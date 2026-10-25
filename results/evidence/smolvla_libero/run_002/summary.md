# SmolVLA + LIBERO 鈥� run_002

- **Status:** completed
- **Exit code:** 0
- **Model:** SmolVLA LIBERO finetuned
- **Suite:** libero_spatial
- **Task ID:** 0
- **Episodes:** 1
- **Seed:** 42
- **GPU:** NVIDIA GeForce RTX 4090 D
- **Start:** 2026-10-02T01:15:24+08:00
- **End:** 2026-10-02T01:16:22+08:00
- **Runtime:** 58s

## Reproduction command

```bash
lerobot-eval --policy.path=/root/autodl-tmp/embodied/models/smolvla_libero --rename_map=\{\"observation.images.image\":\"observation.images.camera1\"\,\"observation.images.image2\":\"observation.images.camera2\"\} --env.type=libero --env.task=libero_spatial --env.task_ids=\[0\] --eval.batch_size=1 --eval.n_episodes=1 --env.max_parallel_tasks=1 --seed=42 --output_dir=/root/autodl-tmp/embodied/results/smolvla_libero/run_002/eval 
```

## Artifacts

See:

- `console.log`
- `system_info.txt`
- `checkpoint_sha256.txt`
- `model_config.json`
- `metrics.csv`
- `metrics.json`
- `artifact_manifest.tsv`
- `eval/`
- `frames/`
