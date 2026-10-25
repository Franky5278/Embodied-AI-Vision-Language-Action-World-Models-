#!/usr/bin/env bash
set -uo pipefail

ROOT="/root/autodl-tmp/embodied"
ENV="/autodl-fs/data/embodied/envs/openvla"
REPO="$ROOT/repos/openvla"
LIBERO_REPO="$ROOT/repos/libero-openvla"

MODEL_ROOT="/autodl-fs/data/embodied/models/openvla"
RESULT_ROOT="$ROOT/results/openvla_libero"

export LIBERO_CONFIG_PATH="$ROOT/configs/openvla_libero"
export PYTHONPATH="$REPO:$LIBERO_REPO:${PYTHONPATH:-}"

export CUDA_VISIBLE_DEVICES=0
export MUJOCO_GL=egl
export TOKENIZERS_PARALLELISM=false

declare -A CKPTS
CKPTS[libero_spatial]="$MODEL_ROOT/openvla-7b-finetuned-libero-spatial"
CKPTS[libero_object]="$MODEL_ROOT/openvla-7b-finetuned-libero-object"
CKPTS[libero_goal]="$MODEL_ROOT/openvla-7b-finetuned-libero-goal"
CKPTS[libero_10]="$MODEL_ROOT/openvla-7b-finetuned-libero-10"

SUITES=(
    libero_spatial
    libero_object
    libero_goal
    libero_10
)

N=1
while true; do
    RUN_DIR=$(printf "%s/mini_benchmark_%03d" "$RESULT_ROOT" "$N")
    [ ! -e "$RUN_DIR" ] && break
    N=$((N+1))
done

mkdir -p "$RUN_DIR"

echo "RUN_DIR=$RUN_DIR"
echo "Protocol: task_ids=0,1 | trials/task=3 | seed=42"
echo

MISSING=0

for SUITE in "${SUITES[@]}"; do
    CKPT="${CKPTS[$SUITE]}"

    if [ -d "$CKPT" ]; then
        echo "[OK] $SUITE -> $CKPT"
    else
        echo "[MISSING] $SUITE -> $CKPT"
        MISSING=1
    fi
done

if [ "$MISSING" -ne 0 ]; then
    echo
    echo "Checkpoint staging incomplete."
    exit 2
fi

OVERALL_RC=0

cd "$RUN_DIR"

for SUITE in "${SUITES[@]}"; do

    CKPT="${CKPTS[$SUITE]}"
    SUITE_DIR="$RUN_DIR/$SUITE"

    mkdir -p "$SUITE_DIR"
    cd "$SUITE_DIR"

    echo
    echo "========================================"
    echo "OPENVLA: $SUITE"
    echo "========================================"

    set +e

    "$ENV/bin/python" \
      "$REPO/experiments/robot/libero/run_libero_eval_subset.py" \
      --model_family openvla \
      --pretrained_checkpoint "$CKPT" \
      --task_suite_name "$SUITE" \
      --task_ids "0,1" \
      --num_trials_per_task 3 \
      --seed 42 \
      --center_crop True \
      --use_wandb False \
      --local_log_dir "$SUITE_DIR/logs" \
      2>&1 | tee "$SUITE_DIR/stdout.log"

    RC=${PIPESTATUS[0]}

    set -e

    echo "$RC" > "$SUITE_DIR/exit_code.txt"

    if [ "$RC" -ne 0 ]; then
        OVERALL_RC=1
        echo "[FAILED] $SUITE"
    else
        echo "[DONE] $SUITE"
    fi

done

echo "$OVERALL_RC" > "$RUN_DIR/overall_exit_code.txt"

echo
echo "========================================"
echo "OPENVLA MINI BENCHMARK FINISHED"
echo "RUN_DIR=$RUN_DIR"
echo "OVERALL_RC=$OVERALL_RC"
echo "========================================"

exit "$OVERALL_RC"
