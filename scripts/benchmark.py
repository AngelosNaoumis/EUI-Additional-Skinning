"""Run a benchmarks/*.lua workload against this addon, and optionally against another copy.

Each workload prints one "MEASURE ..." line; numeric fields are reported as the median of
seven isolated Lua 5.4 states (needs lupa: pip install lupa). These are host timings from
mocks, useful for before/after comparisons, not WoW frame time.

    python scripts/benchmark.py auctionator
    python scripts/benchmark.py auctionator --before path/to/older/EUIAdditionalSkinning
"""
import argparse
import statistics
from pathlib import Path

import lupa.lua54 as lupa

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('bench', help='workload name in benchmarks/, e.g. auctionator or scan')
parser.add_argument('--before', help='another copy of the addon to compare against')
parser.add_argument('--trials', type=int, default=7)
args = parser.parse_args()
source = (root / 'benchmarks' / f'{args.bench}.lua').read_text()


def measure(addon):
    trials = []
    for _ in range(args.trials):
        lua = lupa.LuaRuntime()
        lines = []
        lua.globals().print = lambda *values: lines.append(' '.join(str(v) for v in values))
        lua.globals().BENCH_ROOT = str(Path(addon).resolve()).replace('\\', '/')
        lua.execute(source)
        trials.append([token for token in lines[-1].split()[1:]])
    out = []
    for column in zip(*trials):
        try:
            out.append(f'{statistics.median(float(v) for v in column):.6g}')
        except ValueError:
            out.append(column[0])
    return ' '.join(out)


if args.before:
    print(f'before  {measure(args.before)}')
print(f'current {measure(root / "EUIAdditionalSkinning")}')
