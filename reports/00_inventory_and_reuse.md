# Inventory, reuse and execution validation

The preserved SmolVLA baseline contains a 24-episode summary, four successful suite statuses, raw episode records and 353-second total runtime. It was reused rather than executed again. Setup/import logs for the other projects were not treated as successful rollouts.

The current GPU was an RTX 4090 D. Hardware details, dependency freezes, available source commit identifiers, commands and sampled device memory are captured under `results/evidence/codex_session_20261026`. Some source trees were imported without Git metadata; missing commit identifiers are reported instead of invented.

Legacy compatibility failures and repaired attempts are retained in console logs and failed-attempt JSON files. Valid completed TD-MPC2 stages and OpenVLA suites are skipped on resumption. No checkpoints or successful historical result directories are overwritten.
