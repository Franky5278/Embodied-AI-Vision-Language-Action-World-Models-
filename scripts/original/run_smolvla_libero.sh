#!/usr/bin/env bash
set -uo pipefail

ROOT="/root/autodl-tmp/embodied"
RESULT_ROOT="$ROOT/results/smolvla_libero"
MODEL="$ROOT/models/smolvla_libero"

# ---------- automatic versioning ----------
mkdir -p "$RESULT_ROOT"

N=1
while [ -d "$RESULT_ROOT/run_$(printf '%03d' "$N")" ]; do
    N=$((N+1))
done

RUN_ID="run_$(printf '%03d' "$N")"
RUN_DIR="$RESULT_ROOT/$RUN_ID"
EVAL_DIR="$RUN_DIR/eval"

mkdir -p "$RUN_DIR" "$EVAL_DIR" "$RUN_DIR/frames"

echo "========================================"
echo " SmolVLA + LIBERO"
echo " $RUN_ID"
echo "========================================"

# ---------- environment ----------
source /root/miniconda3/etc/profile.d/conda.sh
conda activate "$ROOT/envs/smolvla-libero"

export MUJOCO_GL=egl
export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_DISABLE_XET=1

START_ISO=$(date -Iseconds)
START_EPOCH=$(date +%s)

# ---------- experiment definition ----------
SUITE="libero_spatial"
TASK_ID="0"
EPISODES="1"
BATCH_SIZE="1"
SEED="42"

CMD=(
    lerobot-eval
    "--policy.path=$MODEL"
    '--rename_map={"observation.images.image":"observation.images.camera1","observation.images.image2":"observation.images.camera2"}'
    "--env.type=libero"
    "--env.task=$SUITE"
    "--env.task_ids=[$TASK_ID]"
    "--eval.batch_size=$BATCH_SIZE"
    "--eval.n_episodes=$EPISODES"
    "--env.max_parallel_tasks=1"
    "--seed=$SEED"
    "--output_dir=$EVAL_DIR"
)

# ---------- save exact command ----------
printf '%q ' "${CMD[@]}" > "$RUN_DIR/command.txt"
printf '\n' >> "$RUN_DIR/command.txt"

# ---------- metadata ----------
cat > "$RUN_DIR/metadata.json" <<EOF
{
  "run_id": "$RUN_ID",
  "model": "SmolVLA",
  "checkpoint": "$MODEL",
  "benchmark": "LIBERO",
  "suite": "$SUITE",
  "task_id": $TASK_ID,
  "episodes": $EPISODES,
  "batch_size": $BATCH_SIZE,
  "seed": $SEED,
  "start_time": "$START_ISO",
  "mujoco_gl": "$MUJOCO_GL"
}
EOF

# ---------- preserve configs ----------
cp "$MODEL/config.json" "$RUN_DIR/model_config.json"
[ -f "$MODEL/train_config.json" ] && \
    cp "$MODEL/train_config.json" "$RUN_DIR/train_config.json"

# ---------- system info ----------
{
    echo "===== DATE ====="
    date -Iseconds

    echo
    echo "===== HOST ====="
    hostname

    echo
    echo "===== GPU ====="
    nvidia-smi

    echo
    echo "===== PYTHON ====="
    which python
    python --version

    echo
    echo "===== PYTORCH ====="
    python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
print("cuda_runtime:", torch.version.cuda)
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
PY

    echo
    echo "===== LEROBOT ====="
    which lerobot-eval
} > "$RUN_DIR/system_info.txt" 2>&1

# ---------- checkpoint identity ----------
sha256sum "$MODEL/model.safetensors" \
    > "$RUN_DIR/checkpoint_sha256.txt"

# ---------- actual evaluation ----------
echo
echo "Starting evaluation..."
echo "Artifacts: $RUN_DIR"
echo

set +e
"${CMD[@]}" 2>&1 | tee "$RUN_DIR/console.log"
EXIT_CODE=${PIPESTATUS[0]}
set -e

END_ISO=$(date -Iseconds)
END_EPOCH=$(date +%s)
DURATION=$((END_EPOCH - START_EPOCH))

# ---------- status ----------
if [ "$EXIT_CODE" -eq 0 ]; then
    STATUS="completed"
else
    STATUS="failed"
fi

cat > "$RUN_DIR/status.json" <<EOF
{
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "end_time": "$END_ISO",
  "duration_seconds": $DURATION
}
EOF

# ---------- artifact inventory ----------
find "$RUN_DIR" -type f \
    -printf '%P\t%s bytes\n' \
    | sort \
    > "$RUN_DIR/artifact_manifest.tsv"

# ---------- extract representative frame if video exists ----------
FIRST_VIDEO=$(find "$RUN_DIR" -type f \
    \( -iname '*.mp4' -o -iname '*.avi' -o -iname '*.webm' \) \
    | head -1)

if [ -n "${FIRST_VIDEO:-}" ] && command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg -y \
        -ss 1 \
        -i "$FIRST_VIDEO" \
        -frames:v 1 \
        "$RUN_DIR/frames/representative_frame.png" \
        >/dev/null 2>&1 || true
fi

# ---------- build generic metrics table from JSON artifacts ----------
python - "$RUN_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])

exclude = {
    "metadata.json",
    "status.json",
    "model_config.json",
    "train_config.json",
}

rows = []

def flatten(obj, prefix=""):
    out = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else str(k)
            out.update(flatten(v, key))
    elif isinstance(obj, (str, int, float, bool)) or obj is None:
        out[prefix] = obj
    return out

for p in run_dir.rglob("*.json"):
    if p.name in exclude:
        continue
    try:
        data = json.loads(p.read_text())
    except Exception:
        continue

    flat = flatten(data)
    for key, value in flat.items():
        rows.append({
            "source": str(p.relative_to(run_dir)),
            "metric": key,
            "value": value,
        })

with open(run_dir / "metrics.csv", "w", newline="") as f:
    writer = csv.DictWriter(
        f,
        fieldnames=["source", "metric", "value"]
    )
    writer.writeheader()
    writer.writerows(rows)

with open(run_dir / "metrics.json", "w") as f:
    json.dump(rows, f, indent=2)

print(f"Extracted {len(rows)} scalar metric entries.")
PY

# ---------- GitHub-readable summary ----------
cat > "$RUN_DIR/summary.md" <<EOF
# SmolVLA + LIBERO 鈥� $RUN_ID

- **Status:** $STATUS
- **Exit code:** $EXIT_CODE
- **Model:** SmolVLA LIBERO finetuned
- **Suite:** $SUITE
- **Task ID:** $TASK_ID
- **Episodes:** $EPISODES
- **Seed:** $SEED
- **GPU:** NVIDIA GeForce RTX 4090 D
- **Start:** $START_ISO
- **End:** $END_ISO
- **Runtime:** ${DURATION}s

## Reproduction command

\`\`\`bash
$(cat "$RUN_DIR/command.txt")
\`\`\`

## Artifacts

See:

- \`console.log\`
- \`system_info.txt\`
- \`checkpoint_sha256.txt\`
- \`model_config.json\`
- \`metrics.csv\`
- \`metrics.json\`
- \`artifact_manifest.tsv\`
- \`eval/\`
- \`frames/\`
EOF

echo
echo "========================================"
echo "RUN FINISHED"
echo "Run:      $RUN_ID"
echo "Status:   $STATUS"
echo "Exit:     $EXIT_CODE"
echo "Runtime:  ${DURATION}s"
echo "Artifacts:"
echo "$RUN_DIR"
echo "========================================"

exit "$EXIT_CODE"
