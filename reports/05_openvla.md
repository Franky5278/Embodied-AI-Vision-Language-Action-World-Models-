# 05. OpenVLA: evaluation report

## Question

Can the available checkpoint execute the prescribed simulation tasks, and what success and deployment cost are observed?

## Protocol and provenance

Benchmark: **LIBERO mini**. Source: `current session`. Seed: 42. VLA target: four suites ¡Á two tasks ¡Á three episodes. TD-MPC2 target: five tasks ¡Á three episodes; faucet attempted with PartNet model 5050. No model training was performed.

## Observations

Valid completed episodes: **24**. Successes: **16**. Episode evaluation errors: **0**. Completion validated: **True**.

| Suite/task | Successes | Episodes |
|---|---:|---:|
| libero_10 | 3 | 6 |
| libero_goal | 4 | 6 |
| libero_object | 3 | 6 |
| libero_spatial | 6 | 6 |

![OpenVLA results](../figures/model_05.png)

![Recorded OpenVLA rollout](../figures/rollout_01.jpg)

Source: `openvla_libero\mini_benchmark_003\libero_10\rollouts\2026_10_26\2026_10_26-01_19_32--episode=1--success=False--task=put_both_the_alphabet_soup_and_the_tomato_sauce_in.mp4`.

## Interpretation

Observed success was 66.7% on this small selected sample. It supports checkpoint-level feasibility and failure analysis, not a universal model ranking. 

## Evidence and reproduction

See [raw evidence](../results/evidence/), [commands and evaluators](../scripts/), [episode records](../results/episodes.json), and [session status](../results/evidence/codex_session_20261026/status.json). Successful process exit alone is not counted as evaluation completion.

![Suite results](../figures/suite_heatmap.png)
