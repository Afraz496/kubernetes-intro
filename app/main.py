"""Toy anomaly scan.

Simulates daily counts for one region, fits a simple baseline, and flags days
that fall outside a percentile threshold. Stands in for a real surveillance
model so the container and Kubernetes plumbing has something to run.
"""

import argparse
import os
import sys

import numpy as np

REGIONS = ["fraser", "vancouver-coastal", "island"]


def simulate(region: str, days: int, seed: int) -> np.ndarray:
    """Generate a seasonal daily count series with a late-period surge."""
    rng = np.random.default_rng(seed + abs(hash(region)) % 1000)
    t = np.arange(days)
    seasonal = 40 + 12 * np.sin(2 * np.pi * t / 365.0)
    counts = rng.poisson(seasonal)
    counts[-10:] = rng.poisson(seasonal[-10:] * 1.8)  # the thing we want to catch
    return counts


def scan(counts: np.ndarray, train_frac: float, percentile: float):
    """Flag test-period days above a threshold learned on the training period."""
    split = int(len(counts) * train_frac)
    train, test = counts[:split], counts[split:]
    threshold = np.percentile(train, percentile)
    flags = np.flatnonzero(test > threshold) + split
    return threshold, flags


def main() -> int:
    parser = argparse.ArgumentParser(description="Run an anomaly scan for one region.")
    parser.add_argument("--region", default=os.environ.get("REGION"))
    parser.add_argument("--days", type=int, default=730)
    parser.add_argument("--percentile", type=float, default=97.5)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    region = args.region
    if region is None:
        # In an Indexed Job, Kubernetes sets this to 0, 1, 2, ...
        index = os.environ.get("JOB_COMPLETION_INDEX")
        if index is None:
            print("No --region given and no JOB_COMPLETION_INDEX set.", file=sys.stderr)
            return 2
        region = REGIONS[int(index) % len(REGIONS)]

    counts = simulate(region, args.days, args.seed)
    threshold, flags = scan(counts, train_frac=0.8, percentile=args.percentile)

    print(f"region      : {region}")
    print(f"days        : {len(counts)}")
    print(f"threshold   : {threshold:.1f} (p{args.percentile} of the training period)")
    print(f"flagged days: {len(flags)}")
    if len(flags):
        print(f"first flag  : day {int(flags[0])} at {int(counts[flags[0]])} counts")
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
