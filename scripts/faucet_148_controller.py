"""Dedicated repair controller. Default is an offline plan; --execute uses SSH.

Never powers on an instance. Only use --execute after the user supplies a GPU.
"""
from pathlib import Path
import argparse,hashlib,json,shlex,subprocess,time,tarfile
from datetime import datetime
BASE=Path(__file__).resolve().parent
REMOTE='/root/autodl-tmp/embodied'
HOST='root@connect.cqa1.seetacloud.com'
KEY=Path.home()/'.ssh/autodl_codex'
def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source,'sha256').hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true')
    parser.add_argument('--repair-on-failure',action='store_true',help='Keep failed run online for repair until independent watchdog shuts it down')
    args=parser.parse_args()
    archive=BASE/'faucet_148_prepared.tar.gz'
    expected=(BASE/'faucet_148_prepared.sha256').read_text().split()[0]
    assert digest(archive)==expected,'Local archive SHA-256 mismatch'
    stamp=datetime.now().strftime('%Y%m%d_%H%M%S')
    output=f'{REMOTE}/results/faucet_148_custom_{stamp}'
    deployment=f'{REMOTE}/scripts/faucet_148_repair_{stamp}'
    local=BASE/'faucet_148_results'/stamp
    print(json.dumps({'execute':args.execute,'output':output,'local_results':str(local),
        'archive_sha256':expected,'episodes':3,'evaluation_timeout_minutes':20,
        'independent_shutdown_deadline_minutes':30,
        'shutdown_after_verified_download':True,'powers_on_instance':False},indent=2),flush=True)
    if not args.execute:
        return
    assert KEY.is_file(),'Local SSH key file not found'
    ssh=['ssh','-i',str(KEY),'-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',
         '-o','ConnectTimeout=15','-p','23405',HOST]
    scp=['scp','-i',str(KEY),'-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',
         '-o','ConnectTimeout=15','-P','23405']
    def remote(command,timeout=45):
        result=subprocess.run(ssh+[command],capture_output=True,text=True,timeout=timeout)
        if result.returncode:
            raise RuntimeError(f'SSH command failed ({result.returncode}): {result.stderr[-1200:]}')
        return result.stdout.strip()
    print('Checking existing instance GPU; no power-on operation',flush=True)
    remote(f"{REMOTE}/envs/tdmpc2/bin/python -c 'import torch; assert torch.cuda.is_available(), \"GPU unavailable\"'")
    remote('mkdir -p '+shlex.quote(deployment))
    subprocess.run(scp+[str(archive),HOST+':'+deployment+'/bundle.tar.gz'],check=True,timeout=120)
    uploaded=remote('sha256sum '+deployment+'/bundle.tar.gz').split()[0]
    assert uploaded==expected,'Remote upload SHA-256 mismatch'
    remote('tar -xzf '+deployment+'/bundle.tar.gz -C '+deployment)
    runner=deployment+'/faucet_148_bundle/run_faucet_148.sh'
    # A separate remote process survives a local app or network disconnect.
    watchdog=f'sleep 1800; bash /usr/bin/shutdown'
    launch=(f'nohup bash -c {shlex.quote(watchdog)} > {deployment}/watchdog.log 2>&1 < /dev/null & '
            f'echo $! > {deployment}/watchdog.pid; '
            f'nohup env FAUCET_OUTPUT_DIR={shlex.quote(output)} bash {shlex.quote(runner)} '
            f'> {deployment}/launch.log 2>&1 < /dev/null & echo $!')
    print('Starting isolated evaluation with independent 30-minute shutdown fallback',flush=True)
    remote(launch)
    local.mkdir(parents=True,exist_ok=False)
    completed=False
    deadline=time.monotonic()+1500
    try:
        while time.monotonic()<deadline:
            status=remote(f'if [ -f {output}/exit_code.txt ]; then cat {output}/exit_code.txt; else echo RUNNING; fi')
            print(datetime.now().isoformat(timespec='seconds'),status,flush=True)
            if status!='RUNNING':
                completed=True
                break
            time.sleep(20)
        if not completed:
            raise TimeoutError('Evaluation did not publish exit_code within 25 minutes; remote watchdog remains armed')
        packed=deployment+'/results.tar.gz'
        remote(f'tar -czf {packed} -C {REMOTE}/results {shlex.quote(output.rsplit("/",1)[1])}',timeout=120)
        remote_hash=remote('sha256sum '+packed).split()[0]
        downloaded=local/'results.tar.gz'
        subprocess.run(scp+[HOST+':'+packed,str(downloaded)],check=True,timeout=180)
        assert digest(downloaded)==remote_hash,'Result download SHA-256 mismatch'
        (local/'SHA256.txt').write_text(remote_hash+'  results.tar.gz\n')
        with tarfile.open(downloaded) as result:
            metrics=[member for member in result.getmembers() if member.name.endswith('/episodes.jsonl')]
            rows=[]
            if metrics:
                rows=[json.loads(line) for line in result.extractfile(metrics[0]).read().decode().splitlines() if line.strip()]
            valid=status=='0' and len(rows)==3 and all(row.get('custom_model_id')=='148' for row in rows)
        summary={'transport_verified':True,'evaluation_exit_code':status,'episodes':len(rows),
                 'evaluation_complete':valid,'protocol':'custom-fixed-faucet-148'}
        (local/'delivery.json').write_text(json.dumps(summary,indent=2))
        print(json.dumps(summary),flush=True)
        if not valid and args.repair_on_failure:
            print('Failed evidence downloaded; limited repair window remains under watchdog.',flush=True)
            return
        print('Results saved and verified. Requesting instance shutdown.',flush=True)
        # The provider shutdown hook can close SSH before returning an exit code.
        outcome=subprocess.run(ssh+['bash /usr/bin/shutdown'],capture_output=True,text=True,timeout=45)
        (local/'shutdown_request.json').write_text(json.dumps({'returncode':outcome.returncode,
            'stdout':outcome.stdout[-1000:],'stderr':outcome.stderr[-1000:],
            'provider_billing_state_verified':False},indent=2))
    except Exception:
        print('Controller interrupted/failed. Independent remote shutdown watchdog remains armed.',flush=True)
        raise
if __name__=='__main__':
    main()
