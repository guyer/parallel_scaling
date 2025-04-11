from pathlib import Path
import pandas as pd
from matplotlib import pyplot as plt
import matplotlib
import json

def plot_metrics(input, output):
    matplotlib.use('Agg')
    fig, axs = plt.subplots(ncols=1, nrows=3, figsize=(10, 24))
    datasets = ["free_energy", "solid_fraction", "tip_position"]
    for metric in input:
        metric = Path(metric)
        with open(metric.parent / "params.json", "r") as f:
            params = json.load(f)
        df = pd.read_csv(metric)
        label = f"dx={params['dx']} dt={params['dt']}"
        for dataset, ax in zip(datasets, axs):
            df.plot("t", dataset, ax=ax, sharex=True,
                    # marker=".", linestyle="", markersize=1,
                    label=label)
    for dataset, ax in zip(datasets, axs):
        ax.set_ylabel(dataset)
    plt.tight_layout()
    plt.savefig(output)

def plot_scan_solver(input, output):
    matplotlib.use('Agg')
    fig, axs = plt.subplots(ncols=1, nrows=3, figsize=(10, 24))
    datasets = ["free_energy", "solid_fraction", "tip_position"]
    for metric in input:
        metric = Path(metric)
        with open(metric.parent / "params.json", "r") as f:
            params = json.load(f)
        df = pd.read_csv(metric)
        label = f"{params['solver']} {params['preconditioner']}"
        for dataset, ax in zip(datasets, axs):
            df.plot("t", dataset, ax=ax, sharex=True,
                    # marker=".", linestyle="", markersize=1,
                    label=label)
    for dataset, ax in zip(datasets, axs):
        ax.set_ylabel(dataset)
    plt.tight_layout()
    plt.savefig(output)
