# 03. OpenPI pi0.5: evaluation report

## Question

Can the available checkpoint execute the prescribed simulation tasks, and what success and deployment cost are observed?

## Protocol and provenance

Benchmark: **LIBERO mini**. Source: `current session`. Seed: 42. VLA target: four suites ¡Á two tasks ¡Á three episodes. TD-MPC2 target: five tasks ¡Á three episodes; faucet attempted with PartNet model 5050. No model training was performed.

## Observations

Valid completed episodes: **0**. Successes: **0**. Episode evaluation errors: **0**. Completion validated: **False**.

| Suite/task | Successes | Episodes |
|---|---:|---:|

## Interpretation

No valid rollout result was obtained. This is an execution failure, not evidence of zero task success. 

## Evidence and reproduction

See [raw evidence](../results/evidence/), [commands and evaluators](../scripts/), [episode records](../results/episodes.json), and [session status](../results/evidence/codex_session_20261026/status.json). Successful process exit alone is not counted as evaluation completion.

![Suite results](../figures/suite_heatmap.png)
