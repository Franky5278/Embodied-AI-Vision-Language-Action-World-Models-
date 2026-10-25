#!/usr/bin/env bash
# Resume only missing OpenVLA suites after fixing MuJoCo/offline loading.
bash /root/autodl-tmp/embodied/scripts/codex_session_20261026/openvla.sh > /root/autodl-tmp/embodied/results/codex_session_20261026/openvla_repair.log 2>&1
echo "$?" > /root/autodl-tmp/embodied/results/codex_session_20261026/openvla_repair_exit_code.txt
exec bash /root/autodl-tmp/embodied/scripts/codex_session_20261026/vla_jepa_core.sh
