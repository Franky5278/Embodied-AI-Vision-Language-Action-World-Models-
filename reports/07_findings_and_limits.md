# Findings and limits

| Model | Benchmark | Completed | Success | Status |
|---|---|---:|---:|---|
| SmolVLA | LIBERO mini | 24 | 17/24 (70.8%) | Complete |
| VLA-JEPA | LIBERO mini | 24 | 24/24 (100.0%) | Complete |
| OpenPI pi0.5 | LIBERO mini | 24 | 23/24 (95.8%) | Complete |
| TD-MPC2 | ManiSkill2 mini | 12 | 9/12 (75.0%) | Incomplete / failed; see evidence |
| OpenVLA | LIBERO mini | 24 | 16/24 (66.7%) | Complete |

These are descriptive checkpoint results on selected tasks. The task sample is small, episodes within a task are correlated, and training data/checkpoint coverage differ. Historical SmolVLA runtime is not a controlled same-session timing comparison. Missing evaluations and asset incompatibilities are limitations, not zero-success policies. TD-MPC2 state-input ManiSkill2 results cannot establish superiority over visual-language LIBERO methods. Supplemental results support only the specific tested perturbation or planning ablation.

The report does not claim official benchmark reproduction, statistical superiority, real-robot generalization, or a novel trained model.
