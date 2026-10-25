#!/usr/bin/env bash

export RUN_KIND="smoke"
export SUITES="libero_spatial"
export TASK_IDS="0"
export EPISODES="1"
export SEED="42"

exec \
/root/autodl-tmp/embodied/scripts/vla_jepa/_run_eval.sh \
"$@"
