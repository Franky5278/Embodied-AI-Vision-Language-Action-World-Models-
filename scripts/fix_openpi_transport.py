from pathlib import Path
import difflib
R=Path('/root/autodl-tmp/embodied');C=R/'scripts/codex_session_20261026'
p=R/'repos/openpi/packages/openpi-client/src/openpi_client/websocket_client_policy.py'
s=p.read_text();b=C/'original_openpi_websocket_client.py'
if not b.exists():b.write_text(s)
s=s.replace('max_size=None, additional_headers=headers','max_size=None, additional_headers=headers, ping_interval=None, ping_timeout=None')
compile(s,str(p),'exec');p.write_text(s)
(C/'openpi_transport.patch').write_text(''.join(difflib.unified_diff(b.read_text().splitlines(True),s.splitlines(True),fromfile='a/packages/openpi-client/src/openpi_client/websocket_client_policy.py',tofile='b/packages/openpi-client/src/openpi_client/websocket_client_policy.py')))
metrics=R/'results/codex_session_20261026/openpi_libero_spatial/videos/episodes.jsonl'
if metrics.exists():metrics.rename(metrics.with_name('episodes_failed_transport.jsonl'))
print('Client keepalive disabled to allow cold JAX compilation; failed metrics preserved separately')
