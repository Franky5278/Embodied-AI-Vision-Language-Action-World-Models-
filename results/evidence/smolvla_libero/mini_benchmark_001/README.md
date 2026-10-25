# SmolVLA + LIBERO Mini Benchmark

## Protocol

- Model: SmolVLA
- Checkpoint: `smolvla_libero`
- Suites: Spatial, Object, Goal, Long
- Tasks per suite: 2
- Task IDs: 0, 1
- Episodes per task: 3
- Planned episodes: 24
- Seed: 42
- Control mode: relative
- GPU: NVIDIA GeForce RTX 4090 D

## Results

| Suite | Successes | Episodes | Success Rate |
|---|---:|---:|---:|
| libero_10 | 2 | 6 | 33.3% |
| libero_goal | 5 | 6 | 83.3% |
| libero_object | 5 | 6 | 83.3% |
| libero_spatial | 5 | 6 | 83.3% |

**Overall success rate:** 70.8%

## Outputs

- `raw_results.csv`
- `summary_by_task.csv`
- `summary_by_suite.csv`
- `benchmark_summary.json`
- `figures/success_rate_by_suite.png`
- `figures/success_rate_by_task.png`
- `failure_cases/`
- `suites/`

## Interpretation

This mini benchmark is used for structured comparison across
SmolVLA, VLA-JEPA, OpenVLA, and OpenPI under the same LIBERO
evaluation protocol.

It is more informative than a single-episode smoke test but is not
intended to replace the full LIBERO evaluation protocol.
