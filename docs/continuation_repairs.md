# Corrective continuation

VLA-JEPA's pre-existing metrics block had inconsistent indentation. The block was repaired and syntax-checked before completing 24 episodes. OpenPI's Tyro function interface requires `--args.*`; the evaluator translates the captured command options accordingly and uses the validated LIBERO simulator environment.

OpenPI's first cold JAX inference exceeded the client's WebSocket keepalive threshold. Keepalive timeouts were disabled for this local-only connection. Failed transport records are retained separately and excluded from policy success denominators. An incorrectly placed environment close was moved outside the episode loop. Each subsequent OpenPI episode uses a fresh seeded simulator and its prescribed fixed LIBERO initial state; this is a documented evaluator adaptation. Valid `(task_id, episode_id)` records are reused on continuation instead of rerunning completed episodes.

The initial automatic shutdown attempt failed because the platform shutdown file has no executable shebang. The invocation was changed to `bash /usr/bin/shutdown`. Earlier shutdown markers record an attempted command, not proof that the instance stopped. The independent shell watchdog is retained as a fallback.
