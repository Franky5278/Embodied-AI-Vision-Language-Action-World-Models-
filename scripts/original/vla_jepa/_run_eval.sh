#!/usr/bin/env bash

set -u
set -o pipefail

# ============================================================
# VLA-JEPA single-GPU LIBERO runner
# ============================================================

ROOT="/root/autodl-tmp/embodied"

REPO="$ROOT/repos/VLA-JEPA"

MODEL_PY="$ROOT/envs/vla-jepa/bin/python"
SIM_PY="$ROOT/envs/vla-jepa-sim/bin/python"

EVAL="$ROOT/scripts/vla_jepa/eval_libero_subset.py"

CKPT="/autodl-fs/data/embodied/models/vla_jepa/VLA-JEPA-HF/LIBERO/checkpoints/VLA-JEPA-LIBERO.pt"

RESULT_ROOT="$ROOT/results/vla_jepa_libero"

PORT=15083

RUN_KIND="${RUN_KIND:-mini_benchmark}"
SUITES="${SUITES:-libero_spatial libero_object libero_goal libero_10}"
TASK_IDS="${TASK_IDS:-0,1}"
EPISODES="${EPISODES:-3}"
SEED="${SEED:-42}"

MODE="${1:-run}"

export PYTHONPATH="$REPO:${PYTHONPATH:-}"
export MUJOCO_GL=egl


# ============================================================
# Preflight
# ============================================================

required_paths=(
    "$MODEL_PY"
    "$SIM_PY"
    "$EVAL"
    "$CKPT"
    "/autodl-fs/data/embodied/models/vla_jepa/Qwen3-VL-2B-Instruct/model.safetensors"
    "/autodl-fs/data/embodied/models/vla_jepa/vjepa2-vitl-fpc64-256/model.safetensors"
    "/autodl-fs/data/embodied/models/vla_jepa/VLA-JEPA-HF/LIBERO/config.yaml"
    "/autodl-fs/data/embodied/models/vla_jepa/VLA-JEPA-HF/LIBERO/dataset_statistics.json"
)

for p in "${required_paths[@]}"; do
    if [[ ! -e "$p" ]]; then
        echo "MISSING: $p"
        exit 1
    fi
done


# ============================================================
# Dry-run mode: NO GPU
# ============================================================

if [[ "$MODE" == "--dry-run" ]]; then
    echo "================================================"
    echo " VLA-JEPA DRY RUN"
    echo "================================================"

    echo "Run kind : $RUN_KIND"
    echo "Suites   : $SUITES"
    echo "Task IDs : $TASK_IDS"
    echo "Episodes : $EPISODES"
    echo "Seed     : $SEED"
    echo "Port     : $PORT"

    echo
    echo "MODEL SERVER:"
    echo "$MODEL_PY deployment/model_server/server_policy.py \\"
    echo "  --ckpt_path $CKPT \\"
    echo "  --port $PORT --use_bf16 --cuda 0"

    echo
    echo "SIMULATOR COMMAND TEMPLATE:"
    echo "$SIM_PY $EVAL \\"
    echo "  --args.pretrained-path $CKPT \\"
    echo "  --args.task-ids $TASK_IDS \\"
    echo "  --args.num-trials-per-task $EPISODES \\"
    echo "  --args.seed $SEED"

    echo
    echo "DRY RUN PASSED"
    echo "NO MODEL LOADED"
    echo "NO GPU USED"

    exit 0
fi


# ============================================================
# Allocate new run_NNN directory 鈥� NEVER OVERWRITE
# ============================================================

idx=1

while true; do
    printf -v tag "%03d" "$idx"
    RUN_DIR="$RESULT_ROOT/${RUN_KIND}_${tag}"

    if [[ ! -e "$RUN_DIR" ]]; then
        break
    fi

    idx=$((idx + 1))
done

mkdir -p "$RUN_DIR"

echo "$RUN_DIR" > "$RESULT_ROOT/latest_${RUN_KIND}.txt"

echo "RUN_DIR=$RUN_DIR"


# ============================================================
# Preserve execution context
# ============================================================

{
    echo "timestamp=$(date -Iseconds)"
    echo "hostname=$(hostname)"
    echo "run_kind=$RUN_KIND"
    echo "suites=$SUITES"
    echo "task_ids=$TASK_IDS"
    echo "episodes=$EPISODES"
    echo "seed=$SEED"
    echo "checkpoint=$CKPT"
    echo "model_python=$MODEL_PY"
    echo "sim_python=$SIM_PY"
} > "$RUN_DIR/run_config.txt"

cp "$EVAL" "$RUN_DIR/eval_libero_subset.py"

cp \
"/autodl-fs/data/embodied/models/vla_jepa/VLA-JEPA-HF/LIBERO/config.yaml" \
"$RUN_DIR/config.yaml"

cp \
"/autodl-fs/data/embodied/models/vla_jepa/VLA-JEPA-HF/LIBERO/dataset_statistics.json" \
"$RUN_DIR/dataset_statistics.json"

(
    cd "$REPO"
    git rev-parse HEAD
    git status --short
) > "$RUN_DIR/git_state.txt" 2>&1 || true

nvidia-smi > "$RUN_DIR/nvidia_smi_before.txt" 2>&1 || true

"$MODEL_PY" - <<'PY' > "$RUN_DIR/torch_gpu_before.txt" 2>&1
import torch

print("torch:", torch.__version__)
print("cuda build:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())

if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
    print(
        "vram_gb:",
        torch.cuda.get_device_properties(0).total_memory / 1024**3
    )
PY


# ============================================================
# GPU requirement
# ============================================================

if ! "$MODEL_PY" - <<'PY'
import sys
import torch
sys.exit(0 if torch.cuda.is_available() else 1)
PY
then
    echo "ERROR: CUDA GPU is not available."
    echo "This script must only be run during the consolidated GPU stage."
    exit 2
fi


# ============================================================
# Start ONE policy server on GPU 0
# ============================================================

cd "$REPO"

export CUDA_VISIBLE_DEVICES=0

"$MODEL_PY" \
deployment/model_server/server_policy.py \
    --ckpt_path "$CKPT" \
    --port "$PORT" \
    --use_bf16 \
    --cuda 0 \
    > "$RUN_DIR/server.log" 2>&1 &

SERVER_PID=$!

echo "$SERVER_PID" > "$RUN_DIR/server.pid"

cleanup() {
    if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
        kill "$SERVER_PID" >/dev/null 2>&1 || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM


# ============================================================
# Wait until websocket server opens its port
# ============================================================

echo "Waiting for policy server..."

SERVER_READY=0

for i in $(seq 1 360); do

    if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
        echo "MODEL SERVER EXITED DURING STARTUP"
        tail -100 "$RUN_DIR/server.log"
        exit 3
    fi

    if "$MODEL_PY" -c \
        "import socket; s=socket.create_connection(('127.0.0.1',$PORT),timeout=1); s.close()" \
        >/dev/null 2>&1
    then
        SERVER_READY=1
        break
    fi

    sleep 2
done

if [[ "$SERVER_READY" != "1" ]]; then
    echo "MODEL SERVER STARTUP TIMEOUT"
    exit 4
fi

echo "MODEL SERVER READY" | tee "$RUN_DIR/server_ready.txt"


# ============================================================
# Run LIBERO suites sequentially
# ============================================================

FAILED_SUITES=0

for SUITE in $SUITES; do

    echo
    echo "================================================"
    echo " START $SUITE"
    echo "================================================"

    SUITE_DIR="$RUN_DIR/$SUITE"
    mkdir -p "$SUITE_DIR"

    START_TS=$(date +%s)

    "$SIM_PY" \
    "$EVAL" \
        --args.pretrained-path "$CKPT" \
        --args.host "127.0.0.1" \
        --args.port "$PORT" \
        --args.task-suite-name "$SUITE" \
        --args.task-ids "$TASK_IDS" \
        --args.num-trials-per-task "$EPISODES" \
        --args.seed "$SEED" \
        --args.video-out-path "$SUITE_DIR/videos" \
        --args.metrics-out-path "$SUITE_DIR/episodes.jsonl" \
        --args.with-state "true" \
        --args.job-name "vla_jepa_${SUITE}" \
        2>&1 | tee "$SUITE_DIR/eval.log"

    RC=${PIPESTATUS[0]}

    END_TS=$(date +%s)

    echo "$RC" > "$SUITE_DIR/exit_code.txt"
    echo "$((END_TS - START_TS))" > "$SUITE_DIR/runtime_seconds.txt"

    if [[ "$RC" -ne 0 ]]; then
        FAILED_SUITES=$((FAILED_SUITES + 1))
        echo "SUITE FAILED: $SUITE RC=$RC"
    else
        echo "SUITE COMPLETE: $SUITE"
    fi

    # If model server itself died, remaining suites cannot run.
    if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
        echo "MODEL SERVER DIED AFTER $SUITE"
        break
    fi

done


# ============================================================
# Aggregate episode JSONL
# ============================================================

"$SIM_PY" - "$RUN_DIR" "$SUITES" "$TASK_IDS" "$EPISODES" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
suites = sys.argv[2].split()
task_ids = [x for x in sys.argv[3].split(",") if x]
episodes_per_task = int(sys.argv[4])

rows = []

for suite in suites:
    f = run_dir / suite / "episodes.jsonl"

    if not f.exists():
        continue

    for line in f.read_text().splitlines():
        if line.strip():
            rows.append(json.loads(line))

tsv = run_dir / "episodes.tsv"

fields = [
    "model",
    "suite",
    "task_id",
    "episode_id",
    "success",
    "seed",
    "task_description",
    "policy_steps",
    "runtime_sec",
    "video_path",
    "server_host",
    "server_port",
]

with tsv.open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fields, delimiter="\t")
    writer.writeheader()

    for row in rows:
        writer.writerow({k: row.get(k, "") for k in fields})

suite_summary = {}

for suite in suites:
    sr = [x for x in rows if x.get("suite") == suite]
    successes = sum(bool(x.get("success")) for x in sr)

    suite_summary[suite] = {
        "episodes_completed": len(sr),
        "successes": successes,
        "success_rate": successes / len(sr) if sr else None,
    }

successes = sum(bool(x.get("success")) for x in rows)

expected = (
    len(suites)
    * len(task_ids)
    * episodes_per_task
)

summary = {
    "model": "VLA-JEPA",
    "protocol": "portfolio_mini_benchmark",
    "expected_episodes": expected,
    "episodes_completed": len(rows),
    "successes": successes,
    "success_rate": successes / len(rows) if rows else None,
    "suite_summary": suite_summary,
}

(run_dir / "summary.json").write_text(
    json.dumps(summary, indent=2)
)

print(json.dumps(summary, indent=2))
PY


# ============================================================
# Final artifacts
# ============================================================

nvidia-smi > "$RUN_DIR/nvidia_smi_after.txt" 2>&1 || true

{
    echo "failed_suites=$FAILED_SUITES"
    echo "completed=$(date -Iseconds)"
} > "$RUN_DIR/run_status.txt"

find "$RUN_DIR" -type f \
-printf "%P\t%s\n" \
| sort \
> "$RUN_DIR/artifact_manifest.tsv"

echo
echo "================================================"
echo " VLA-JEPA RUN COMPLETE"
echo "================================================"
echo "Artifacts: $RUN_DIR"

if [[ "$FAILED_SUITES" -ne 0 ]]; then
    exit 10
fi

exit 0
