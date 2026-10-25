from pathlib import Path
import difflib
R=Path('/root/autodl-tmp/embodied');C=R/'scripts/codex_session_20261026';p=C/'openpi_eval.py';s=p.read_text()
backup=C/'openpi_eval_before_reset_fix.py'
if not backup.exists():backup.write_text(s)
s=s.replace('    # Start evaluation\n    total_episodes, total_successes = 0, 0','''    # Resume only valid completed episodes; preserve evaluation errors as evidence.
    metrics_file = pathlib.Path(args.video_out_path)/"episodes.jsonl"
    previous = []
    if metrics_file.exists():
        for line in metrics_file.read_text().splitlines():
            if line.strip():
                record=json.loads(line)
                if not record.get("error"): previous.append(record)
    completed_ids={(r["task_id"],r["episode_id"]) for r in previous}
    total_episodes=len(previous)
    total_successes=sum(bool(r["success"]) for r in previous)''')
s=s.replace('        task_episodes, task_successes = 0, 0','''        task_episodes = sum(r["task_id"]==task_id for r in previous)
        task_successes = sum(bool(r["success"]) for r in previous if r["task_id"]==task_id)''')
s=s.replace('        for episode_idx in tqdm.tqdm(range(args.num_trials_per_task)):\n','''        for episode_idx in tqdm.tqdm(range(args.num_trials_per_task)):
            if (task_id, episode_idx) in completed_ids:
                logging.info("Reuse valid task %s episode %s", task_id, episode_idx)
                continue
            # Independent fresh simulation prevents reset state leakage across episodes.
            if episode_idx > 0:
                env.close()
                env, task_description = _get_libero_env(task, LIBERO_ENV_RESOLUTION, args.seed)
''')
compile(s,str(p),'exec');p.write_text(s)
(C/'openpi_reset_resume.patch').write_text(''.join(difflib.unified_diff(backup.read_text().splitlines(True),s.splitlines(True),fromfile='a/openpi_eval.py',tofile='b/openpi_eval.py')))
print('OpenPI evaluator resumes valid episodes and creates fresh seeded environments')
