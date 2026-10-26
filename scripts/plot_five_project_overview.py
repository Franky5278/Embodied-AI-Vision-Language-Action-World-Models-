"""Five-project overview, keeping different evaluation protocols separate."""
from pathlib import Path
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'results/summary.json').read_text())
lookup={row['model']:row for row in rows}
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':11})
fig,axes=plt.subplots(1,2,figsize=(14,6),gridspec_kw={'width_ratios':[1.65,1]},facecolor='#f8fafc')
left,right=axes
names=['SmolVLA','VLA-JEPA','OpenPI pi0.5','OpenVLA']
colors=['#2563eb','#7c3aed','#f59e0b','#10b981']
for i,(name,color) in enumerate(zip(names,colors)):
    row=lookup[name];rate=row['success_rate_pct']
    left.bar(i,rate,color=color,width=.7)
    left.errorbar(i,rate,yerr=[[rate-row['wilson95_low']],[row['wilson95_high']-rate]],fmt='none',ecolor='#475569',capsize=4)
    left.text(i,rate+3,f"{row['successes']}/{row['episodes']}",ha='center',fontweight='bold')
left.set_xticks(range(4),names);left.set_title('Four VLA projects · LIBERO mini',pad=15,fontweight='bold')
left.set_ylabel('Episode success (%)')
right.bar([0,1],[75,100],color=['#0891b2','#22c55e'],width=.58)
right.set_xticks([0,1],['Original four tasks\n9/12 successful','Custom Faucet 148\n3/3 successful'])
right.set_title('Fifth project · TD-MPC2 / ManiSkill2',pad=15,fontweight='bold')
for i,rate in enumerate([75,100]):right.text(i,rate+3,f'{rate}%',ha='center',fontweight='bold')
right.set_ylabel('Episode success (%)')
for ax in axes:
    ax.set_facecolor('#f8fafc');ax.set_ylim(0,116);ax.set_yticks(range(0,101,20))
    ax.grid(axis='y',alpha=.15);ax.set_axisbelow(True)
    ax.spines[['top','right']].set_visible(False)
fig.suptitle('Five embodied-control projects · completed runs and faucet repair',fontsize=17,fontweight='bold',y=.98)
fig.text(.5,.065,'Separate benchmarks: LIBERO policies and state-input ManiSkill2 planning are not a common ranking.',ha='center',fontsize=11)
fig.text(.5,.025,'Faucet 148 is a separately labeled replacement asset, not legacy 5050. LIBERO error bars: descriptive 95% Wilson intervals.',ha='center',fontsize=10,color='#475569')
fig.tight_layout(rect=[0,.12,1,.94]);fig.savefig(ROOT/'figures/five_project_overview.png',dpi=180);plt.close(fig)
