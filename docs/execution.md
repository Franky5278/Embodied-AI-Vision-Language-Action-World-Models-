# Execution notes

This session performs checkpoint evaluation, not new model training. Baselines are serialized on one RTX 4090 D. SmolVLA mini_benchmark_001 is reused after checking its 24-episode summary and successful suite statuses.

Repairs: migrated OpenVLA environment and checkpoint paths are redirected to the local data disk. OpenVLA loads its already registered local HF classes instead of resolving remote auto_map code. TD-MPC2 wrappers are aligned with legacy Gym because ManiSkill2 0.4 registers environments there; original files and a compatibility patch are preserved. A legacy StackCube checkpoint receives module-key renaming with tensor values unchanged. Existing YCB collision meshes are converted from PLY to OBJ. NVIDIA Vulkan ICD is explicitly selected. OpenPI episode videos use unique task/episode filenames, and structured metrics capture exceptions separately from failures. Evaluators record available inference timing; it includes transport for OpenPI and explicit CUDA synchronization for TD-MPC2, so these are not interchangeable measures.

The runner uses a four-hour execution budget and per-stage timeouts. An independent watchdog requests AutoDL shutdown after 15000 seconds. After GPU completion, at most ten minutes are allowed for verified local download; then AutoDL's documented /usr/bin/shutdown mechanism is called regardless of local connectivity. GitHub publication runs on the Windows computer and does not require keeping the GPU instance running.

Every stage keeps commands, logs and exit codes. Nonzero exit is an execution error; zero exit requires validating actual episode counts. If the runner is restarted during repair, earlier logs remain and any repeated failed attempts are documented. Completed valid rollouts are reused.
