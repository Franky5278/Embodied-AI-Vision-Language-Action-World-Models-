#!/usr/bin/env bash
# Runs only the missing task, with a fresh output directory and a 20-minute cap.
# No instance power operations are performed by this preparation script.
set -euo pipefail
ROOT=/root/autodl-tmp/embodied
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec 9>"$ROOT/results/faucet_repair.lock"
flock -n 9 || { echo 'Another faucet repair is running'; exit 1; }
"$ROOT/envs/tdmpc2/bin/python" -c 'import torch; assert torch.cuda.is_available(), "No GPU: evaluation not started"'
OUT="${FAUCET_OUTPUT_DIR:-$ROOT/results/faucet_148_custom_$(date +%Y%m%d_%H%M%S)}"
[[ "$OUT" == "$ROOT/results/faucet_148_custom_"* ]] || { echo 'Invalid output path'; exit 1; }
[[ ! -e "$OUT" ]] || { echo 'Output already exists; refusing to overwrite'; exit 1; }
mkdir -p "$OUT"
export EXPERIMENT_METRICS="$OUT/episodes.jsonl"
export EXPERIMENT_VIDEO_DIR="$OUT"
export VK_ICD_FILENAMES=/etc/vulkan/icd.d/nvidia_icd.json
export PYTHONPATH="$ROOT/repos/tdmpc2/tdmpc2"
cd "$ROOT/repos/tdmpc2/tdmpc2"
set +e
timeout --signal=TERM --kill-after=30s 1200s "$ROOT/envs/tdmpc2/bin/python" "$HERE/run_faucet_148.py" \
 task=turn-faucet model_size=5 checkpoint="$ROOT/models/tdmpc2/turn-faucet-1.pt" \
 eval_episodes=3 save_video=true seed=42 compile=false mpc=true enable_wandb=false \
 hydra.run.dir="$OUT" 2>&1 | tee "$OUT/run.log"
STATUS=${PIPESTATUS[0]}
set -e
printf '%s\n' "$STATUS" > "$OUT/exit_code.txt"
echo "Output: $OUT; exit code: $STATUS"
exit "$STATUS"
