# SmolVLA + LIBERO 鈥� run_001

- **Status:** failed
- **Exit code:** 1
- **Model:** SmolVLA LIBERO finetuned
- **Suite:** libero_spatial
- **Task ID:** 0
- **Episodes:** 1
- **Seed:** 42
- **GPU:** NVIDIA GeForce RTX 4090 D
- **Start:** 2026-10-02T01:05:44+08:00
- **End:** 2026-10-02T01:09:29+08:00
- **Runtime:** 225s

## Reproduction command

```bash
lerobot-eval --policy.path=/root/autodl-tmp/embodied/models/smolvla_libero --env.type=libero --env.task=libero_spatial --env.task_ids=\[0\] --eval.batch_size=1 --eval.n_episodes=1 --env.max_parallel_tasks=1 --seed=42 --output_dir=/root/autodl-tmp/embodied/results/smolvla_libero/run_001/eval 
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
