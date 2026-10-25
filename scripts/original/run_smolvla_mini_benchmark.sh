#!/usr/bin/env bash
set -uo pipefail

ROOT="/root/autodl-tmp/embodied"
MODEL="$ROOT/models/smolvla_libero"
RESULT_ROOT="$ROOT/results/smolvla_libero"

source /root/miniconda3/etc/profile.d/conda.sh
conda activate "$ROOT/envs/smolvla-libero"

export MUJOCO_GL=egl
export HF_ENDPOINT=https://hf-mirror.com
export HF_HUB_DISABLE_XET=1

# ==========================================
# Automatic benchmark versioning
# ==========================================
N=1
while [ -d "$RESULT_ROOT/mini_benchmark_$(printf '%03d' "$N")" ]; do
    N=$((N+1))
done

BENCH_ID="mini_benchmark_$(printf '%03d' "$N")"
BENCH_DIR="$RESULT_ROOT/$BENCH_ID"

mkdir -p \
    "$BENCH_DIR/suites" \
    "$BENCH_DIR/figures" \
    "$BENCH_DIR/failure_cases"

START_ISO=$(date -Iseconds)
START_EPOCH=$(date +%s)

SUITES=(
    "libero_spatial"
    "libero_object"
    "libero_goal"
    "libero_10"
)

TASK_IDS='[0,1]'
EPISODES=3
BATCH_SIZE=1
SEED=42

echo "========================================"
echo " SmolVLA + LIBERO Mini Benchmark"
echo " $BENCH_ID"
echo "========================================"
echo "Suites: ${SUITES[*]}"
echo "Task IDs: $TASK_IDS"
echo "Episodes/task: $EPISODES"
echo "Seed: $SEED"
echo "Total planned episodes: 24"
echo

# ==========================================
# Benchmark metadata
# ==========================================
cat > "$BENCH_DIR/benchmark_config.json" <<EOF
{
  "benchmark_id": "$BENCH_ID",
  "model": "SmolVLA",
  "checkpoint": "$MODEL",
  "benchmark": "LIBERO",
  "suites": [
    "libero_spatial",
    "libero_object",
    "libero_goal",
    "libero_10"
  ],
  "task_ids": [0, 1],
  "episodes_per_task": 3,
  "total_planned_episodes": 24,
  "batch_size": 1,
  "seed": 42,
  "control_mode": "relative",
  "start_time": "$START_ISO"
}
EOF

sha256sum "$MODEL/model.safetensors" \
    > "$BENCH_DIR/checkpoint_sha256.txt"

cp "$MODEL/config.json" "$BENCH_DIR/model_config.json"

[ -f "$MODEL/train_config.json" ] && \
    cp "$MODEL/train_config.json" "$BENCH_DIR/train_config.json"

# ==========================================
# System information
# ==========================================
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
    echo "===== TORCH ====="
    python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
print("cuda_runtime:", torch.version.cuda)
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
    print(
        "vram_gb:",
        round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 2)
    )
PY
} > "$BENCH_DIR/system_info.txt" 2>&1

# ==========================================
# Run each suite independently
# ==========================================
FAILED_SUITES=0
SUITE_INDEX=0

for SUITE in "${SUITES[@]}"; do

    SUITE_INDEX=$((SUITE_INDEX + 1))
    SUITE_DIR="$BENCH_DIR/suites/$(printf '%02d' "$SUITE_INDEX")_${SUITE}"

    mkdir -p "$SUITE_DIR/eval" "$SUITE_DIR/frames"

    echo
    echo "========================================"
    echo "SUITE $SUITE_INDEX / ${#SUITES[@]}"
    echo "$SUITE"
    echo "========================================"

    CMD=(
        lerobot-eval
        "--policy.path=$MODEL"
        '--rename_map={"observation.images.image":"observation.images.camera1","observation.images.image2":"observation.images.camera2"}'
        "--env.type=libero"
        "--env.task=$SUITE"
        "--env.task_ids=$TASK_IDS"
        "--eval.batch_size=$BATCH_SIZE"
        "--eval.n_episodes=$EPISODES"
        "--env.max_parallel_tasks=1"
        "--seed=$SEED"
        "--output_dir=$SUITE_DIR/eval"
    )

    printf '%q ' "${CMD[@]}" > "$SUITE_DIR/command.txt"
    printf '\n' >> "$SUITE_DIR/command.txt"

    SUITE_START=$(date +%s)
    SUITE_START_ISO=$(date -Iseconds)

    set +e
    "${CMD[@]}" 2>&1 | tee "$SUITE_DIR/console.log"
    EXIT_CODE=${PIPESTATUS[0]}
    set -e

    SUITE_END=$(date +%s)
    SUITE_DURATION=$((SUITE_END - SUITE_START))

    if [ "$EXIT_CODE" -eq 0 ]; then
        STATUS="completed"
    else
        STATUS="failed"
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi

    cat > "$SUITE_DIR/status.json" <<EOF
{
  "suite": "$SUITE",
  "task_ids": [0, 1],
  "episodes_per_task": 3,
  "seed": 42,
  "status": "$STATUS",
  "exit_code": $EXIT_CODE,
  "start_time": "$SUITE_START_ISO",
  "duration_seconds": $SUITE_DURATION
}
EOF

    # --------------------------------------
    # Generate representative frames
    # using OpenCV (no ffmpeg dependency)
    # --------------------------------------
    python - "$SUITE_DIR" <<'PY'
import cv2
import json
import sys
from pathlib import Path

suite_dir = Path(sys.argv[1])
videos = sorted(suite_dir.rglob("*.mp4"))

records = []

for i, video in enumerate(videos):
    cap = cv2.VideoCapture(str(video))

    if not cap.isOpened():
        records.append({
            "video": str(video),
            "decode_ok": False
        })
        continue

    fps = cap.get(cv2.CAP_PROP_FPS)
    n = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    middle = max(0, n // 2)
    cap.set(cv2.CAP_PROP_POS_FRAMES, middle)
    ok, frame = cap.read()

    if not ok:
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        ok, frame = cap.read()

    frame_path = suite_dir / "frames" / f"episode_{i:03d}.png"

    if ok:
        cv2.imwrite(str(frame_path), frame)

    cap.release()

    records.append({
        "video": str(video.relative_to(suite_dir)),
        "decode_ok": bool(ok),
        "width": w,
        "height": h,
        "fps": fps,
        "frames": n,
        "duration_seconds": n / fps if fps else None,
        "representative_frame": (
            str(frame_path.relative_to(suite_dir))
            if ok else None
        )
    })

with open(suite_dir / "video_manifest.json", "w") as f:
    json.dump(records, f, indent=2)

print(f"Processed {len(videos)} videos.")
PY

    find "$SUITE_DIR" \
        -type f \
        ! -name artifact_manifest.tsv \
        -printf '%P\t%s bytes\n' \
        | sort \
        > "$SUITE_DIR/artifact_manifest.tsv"

    echo
    echo "Suite: $SUITE"
    echo "Status: $STATUS"
    echo "Runtime: ${SUITE_DURATION}s"

done

# ==========================================
# Aggregate all eval_info.json files
# ==========================================
python - "$BENCH_DIR" <<'PY'
import csv
import json
import sys
from collections import defaultdict
from pathlib import Path

bench = Path(sys.argv[1])

task_rows = []
episode_rows = []

def find_task_entries(obj):
    """
    Recursively find dictionaries that look like LeRobot
    per-task aggregated results.
    """
    found = []

    if isinstance(obj, dict):
        if (
            "task_group" in obj
            and "task_id" in obj
            and "metrics" in obj
        ):
            found.append(obj)

        for value in obj.values():
            found.extend(find_task_entries(value))

    elif isinstance(obj, list):
        for value in obj:
            found.extend(find_task_entries(value))

    return found


for eval_file in sorted(bench.rglob("eval_info.json")):
    try:
        data = json.loads(eval_file.read_text())
    except Exception as e:
        print("Could not parse", eval_file, e)
        continue

    entries = find_task_entries(data)

    seen = set()

    for entry in entries:
        suite = entry.get("task_group")
        task_id = entry.get("task_id")
        metrics = entry.get("metrics", {})

        identity = (suite, task_id)

        if identity in seen:
            continue

        seen.add(identity)

        successes = metrics.get("successes", [])
        rewards = metrics.get("sum_rewards", [])
        max_rewards = metrics.get("max_rewards", [])
        videos = metrics.get("video_paths", [])

        n_episodes = entry.get(
            "n_episodes",
            len(successes)
        )

        n_success = entry.get(
            "n_success",
            sum(bool(x) for x in successes)
        )

        pc_success = entry.get(
            "pc_success",
            100.0 * n_success / n_episodes
            if n_episodes else None
        )

        ci = entry.get("pc_success_ci95", [None, None])

        task_rows.append({
            "suite": suite,
            "task_id": task_id,
            "n_episodes": n_episodes,
            "n_success": n_success,
            "success_rate": pc_success,
            "ci95_low": ci[0] if len(ci) > 0 else None,
            "ci95_high": ci[1] if len(ci) > 1 else None,
            "avg_sum_reward": (
                sum(rewards) / len(rewards)
                if rewards else None
            ),
            "avg_max_reward": (
                sum(max_rewards) / len(max_rewards)
                if max_rewards else None
            ),
        })

        max_len = max(
            len(successes),
            len(rewards),
            len(videos)
        )

        for ep in range(max_len):
            success = (
                successes[ep]
                if ep < len(successes)
                else None
            )

            reward = (
                rewards[ep]
                if ep < len(rewards)
                else None
            )

            video = (
                videos[ep]
                if ep < len(videos)
                else None
            )

            episode_rows.append({
                "suite": suite,
                "task_id": task_id,
                "episode_id": ep,
                "success": success,
                "sum_reward": reward,
                "video_path": video,
            })


task_rows = sorted(
    task_rows,
    key=lambda x: (x["suite"], x["task_id"])
)

episode_rows = sorted(
    episode_rows,
    key=lambda x: (
        x["suite"],
        x["task_id"],
        x["episode_id"]
    )
)

# -------------------------
# Per-task CSV
# -------------------------
task_fields = [
    "suite",
    "task_id",
    "n_episodes",
    "n_success",
    "success_rate",
    "ci95_low",
    "ci95_high",
    "avg_sum_reward",
    "avg_max_reward",
]

with open(bench / "summary_by_task.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=task_fields)
    w.writeheader()
    w.writerows(task_rows)

# -------------------------
# Raw per-episode CSV
# -------------------------
episode_fields = [
    "suite",
    "task_id",
    "episode_id",
    "success",
    "sum_reward",
    "video_path",
]

with open(bench / "raw_results.csv", "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=episode_fields)
    w.writeheader()
    w.writerows(episode_rows)

# -------------------------
# Per-suite summary
# -------------------------
suite_stats = defaultdict(
    lambda: {
        "episodes": 0,
        "success": 0
    }
)

for r in task_rows:
    suite_stats[r["suite"]]["episodes"] += int(
        r["n_episodes"]
    )
    suite_stats[r["suite"]]["success"] += int(
        r["n_success"]
    )

suite_rows = []

for suite, d in sorted(suite_stats.items()):
    rate = (
        100.0 * d["success"] / d["episodes"]
        if d["episodes"] else 0.0
    )

    suite_rows.append({
        "suite": suite,
        "n_episodes": d["episodes"],
        "n_success": d["success"],
        "success_rate": rate,
    })

with open(bench / "summary_by_suite.csv", "w", newline="") as f:
    w = csv.DictWriter(
        f,
        fieldnames=[
            "suite",
            "n_episodes",
            "n_success",
            "success_rate"
        ]
    )
    w.writeheader()
    w.writerows(suite_rows)

total_eps = sum(x["n_episodes"] for x in suite_rows)
total_success = sum(x["n_success"] for x in suite_rows)

overall = {
    "total_episodes": total_eps,
    "total_success": total_success,
    "overall_success_rate": (
        100.0 * total_success / total_eps
        if total_eps else None
    ),
    "suite_results": suite_rows,
    "task_results": task_rows,
}

with open(bench / "benchmark_summary.json", "w") as f:
    json.dump(overall, f, indent=2)

print()
print("===== AGGREGATED BENCHMARK =====")
print("Episodes:", total_eps)
print("Successes:", total_success)
print(
    "Success rate:",
    overall["overall_success_rate"]
)

for row in suite_rows:
    print(
        row["suite"],
        f'{row["n_success"]}/{row["n_episodes"]}',
        f'{row["success_rate"]:.1f}%'
    )
PY

# ==========================================
# Generate plots
# ==========================================
python - "$BENCH_DIR" <<'PY'
import csv
import sys
from pathlib import Path

import matplotlib.pyplot as plt

bench = Path(sys.argv[1])

# -------------------------
# Suite plot
# -------------------------
suite_csv = bench / "summary_by_suite.csv"

if suite_csv.exists():
    with open(suite_csv) as f:
        rows = list(csv.DictReader(f))

    if rows:
        names = [r["suite"] for r in rows]
        values = [float(r["success_rate"]) for r in rows]

        plt.figure(figsize=(8, 5))
        plt.bar(names, values)
        plt.ylim(0, 100)
        plt.ylabel("Success Rate (%)")
        plt.xlabel("LIBERO Suite")
        plt.title("SmolVLA LIBERO Mini Benchmark")
        plt.xticks(rotation=20)
        plt.tight_layout()
        plt.savefig(
            bench / "figures/success_rate_by_suite.png",
            dpi=180
        )
        plt.close()

# -------------------------
# Task plot
# -------------------------
task_csv = bench / "summary_by_task.csv"

if task_csv.exists():
    with open(task_csv) as f:
        rows = list(csv.DictReader(f))

    if rows:
        labels = [
            f'{r["suite"]}\nT{r["task_id"]}'
            for r in rows
        ]
        values = [
            float(r["success_rate"])
            for r in rows
        ]

        plt.figure(figsize=(11, 5))
        plt.bar(labels, values)
        plt.ylim(0, 100)
        plt.ylabel("Success Rate (%)")
        plt.xlabel("Task")
        plt.title("SmolVLA Task-Level Success Rate")
        plt.xticks(rotation=30, ha="right")
        plt.tight_layout()
        plt.savefig(
            bench / "figures/success_rate_by_task.png",
            dpi=180
        )
        plt.close()

print("Plots generated.")
PY

# ==========================================
# Copy failure cases
# ==========================================
python - "$BENCH_DIR" <<'PY'
import csv
import shutil
import sys
from pathlib import Path

bench = Path(sys.argv[1])
csv_path = bench / "raw_results.csv"
failure_dir = bench / "failure_cases"
failure_dir.mkdir(exist_ok=True)

if not csv_path.exists():
    raise SystemExit

with open(csv_path) as f:
    rows = list(csv.DictReader(f))

count = 0

for row in rows:
    success = str(row["success"]).lower()

    if success in ("true", "1"):
        continue

    path = row.get("video_path")

    if not path:
        continue

    src = Path(path)

    if not src.exists():
        continue

    dst = failure_dir / (
        f'{row["suite"]}_'
        f'task{row["task_id"]}_'
        f'ep{row["episode_id"]}.mp4'
    )

    shutil.copy2(src, dst)
    count += 1

print(f"Copied {count} failure videos.")
PY

# ==========================================
# Benchmark README
# ==========================================
python - "$BENCH_DIR" <<'PY'
import csv
import json
import sys
from pathlib import Path

bench = Path(sys.argv[1])

summary_path = bench / "benchmark_summary.json"

if summary_path.exists():
    summary = json.loads(summary_path.read_text())
else:
    summary = {}

suite_rows = []

p = bench / "summary_by_suite.csv"

if p.exists():
    with open(p) as f:
        suite_rows = list(csv.DictReader(f))

table = [
    "| Suite | Successes | Episodes | Success Rate |",
    "|---|---:|---:|---:|",
]

for r in suite_rows:
    table.append(
        f'| {r["suite"]} | '
        f'{r["n_success"]} | '
        f'{r["n_episodes"]} | '
        f'{float(r["success_rate"]):.1f}% |'
    )

overall = summary.get("overall_success_rate")

if overall is None:
    overall_text = "N/A"
else:
    overall_text = f"{overall:.1f}%"

text = f"""# SmolVLA + LIBERO Mini Benchmark

## Protocol

- Model: SmolVLA
- Checkpoint: `smolvla_libero`
- Suites: Spatial, Object, Goal, Long
- Tasks per suite: 2
- Task IDs: 0, 1
- Episodes per task: 3
- Planned episodes: 24
- Seed: 42
- Control mode: relative
- GPU: NVIDIA GeForce RTX 4090 D

## Results

{chr(10).join(table)}

**Overall success rate:** {overall_text}

## Outputs

- `raw_results.csv`
- `summary_by_task.csv`
- `summary_by_suite.csv`
- `benchmark_summary.json`
- `figures/success_rate_by_suite.png`
- `figures/success_rate_by_task.png`
- `failure_cases/`
- `suites/`

## Interpretation

This mini benchmark is used for structured comparison across
SmolVLA, VLA-JEPA, OpenVLA, and OpenPI under the same LIBERO
evaluation protocol.

It is more informative than a single-episode smoke test but is not
intended to replace the full LIBERO evaluation protocol.
"""

(bench / "README.md").write_text(text)

print("README generated.")
PY

# ==========================================
# Final benchmark status
# ==========================================
END_ISO=$(date -Iseconds)
END_EPOCH=$(date +%s)
TOTAL_DURATION=$((END_EPOCH - START_EPOCH))

cat > "$BENCH_DIR/status.json" <<EOF
{
  "benchmark_id": "$BENCH_ID",
  "failed_suites": $FAILED_SUITES,
  "start_time": "$START_ISO",
  "end_time": "$END_ISO",
  "duration_seconds": $TOTAL_DURATION
}
EOF

find "$BENCH_DIR" \
    -type f \
    ! -name artifact_manifest.tsv \
    -printf '%P\t%s bytes\n' \
    | sort \
    > "$BENCH_DIR/artifact_manifest.tsv"

echo
echo "========================================"
echo "MINI BENCHMARK FINISHED"
echo "Benchmark: $BENCH_ID"
echo "Failed suites: $FAILED_SUITES"
echo "Runtime: ${TOTAL_DURATION}s"
echo "Artifacts:"
echo "$BENCH_DIR"
echo "========================================"

exit 0
