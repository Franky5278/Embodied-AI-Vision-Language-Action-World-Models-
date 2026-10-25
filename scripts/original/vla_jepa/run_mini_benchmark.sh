#!/usr/bin/env bash

export RUN_KIND="mini_benchmark"
export SUITES="libero_spatial libero_object libero_goal libero_10"
export TASK_IDS="0,1"
export EPISODES="3"
export SEED="42"

exec \
/root/autodl-tmp/embodied/scripts/vla_jepa/_run_eval.sh \
"$@"
