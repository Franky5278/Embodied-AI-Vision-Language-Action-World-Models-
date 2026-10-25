# SmolVLA + LIBERO Reproduction

## Experiment

| Item | Value |
|---|---|
| Model | SmolVLA |
| Checkpoint | `smolvla_libero` |
| Benchmark | LIBERO |
| Suite | `libero_spatial` |
| Task ID | 0 |
| Episodes | 1 |
| Seed | 42 |
| GPU | NVIDIA GeForce RTX 4090 D |
| Control Mode | Relative |

## Result

| Metric | Result |
|---|---:|
| Successful Episodes | 1 / 1 |
| Success Rate | 100.0% |
| Average Sum Reward | 1.0 |
| Average Max Reward | 1.0 |
| Evaluation Time | 19.00 s |
| Run Status | Completed |

> This is a single-episode smoke test used to validate the complete
> SmolVLA + LIBERO inference pipeline. The 1/1 success rate should not
> be interpreted as a statistically reliable benchmark result.

## Demo

Simulation video:

`eval/videos/libero_spatial_0/eval_episode_0.mp4`

Representative frame:

`frames/representative_frame.png`

## Reproducibility Artifacts

- `command.txt` 鈥� exact evaluation command
- `console.log` 鈥� complete console output
- `metrics.csv` / `metrics.json` 鈥� structured evaluation metrics
- `result_summary.csv` 鈥� compact result table
- `eval/eval_info.json` 鈥� original LeRobot evaluation output
- `system_info.txt` 鈥� hardware and software environment
- `checkpoint_sha256.txt` 鈥� model checkpoint identity
- `model_config.json` 鈥� policy configuration
- `train_config.json` 鈥� training configuration from checkpoint
- `video_info.json` 鈥� simulation video metadata
