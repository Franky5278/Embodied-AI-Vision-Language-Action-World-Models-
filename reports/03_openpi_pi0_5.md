# 03. OpenPI pi0.5: evaluation report

## Question

Can the available checkpoint execute the prescribed simulation tasks, and what success and deployment cost are observed?

## Protocol and provenance

Benchmark: **LIBERO mini**. Source: `current session`. Seed: 42. VLA target: four suites ¡Á two tasks ¡Á three episodes. TD-MPC2 target: five tasks ¡Á three episodes; faucet attempted with PartNet model 5050. No model training was performed.

## Observations

Valid completed episodes: **24**. Successes: **23**. Episode evaluation errors: **0**. Completion validated: **True**.

| Suite/task | Successes | Episodes |
|---|---:|---:|
| libero_10 | 6 | 6 |
| libero_goal | 5 | 6 |
| libero_object | 6 | 6 |
| libero_spatial | 6 | 6 |

![OpenPI pi0.5 results](../figures/model_03.png)

![Recorded OpenPI pi0.5 rollout](../figures/rollout_03.jpg)

Source: `codex_session_20261026\openpi_libero_spatial\videos\task0_ep0_failure.mp4`.

## Interpretation

Observed success was 95.8% on this small selected sample. It supports checkpoint-level feasibility and failure analysis, not a universal model ranking. 

## Evidence and reproduction

See [raw evidence](../results/evidence/), [commands and evaluators](../scripts/), [episode records](../results/episodes.json), and [session status](../results/evidence/codex_session_20261026/status.json). Successful process exit alone is not counted as evaluation completion.

![Suite results](../figures/suite_heatmap.png)

## Recorded inference timing

780 calls; median 107.3 ms; p95 112.1 ms. Scope differs across evaluators; do not use as a universal cross-model latency ranking.
