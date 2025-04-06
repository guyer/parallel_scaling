from pathlib import Path
import pandas as pd
from matplotlib import pyplot as plt
import matplotlib
import json

def plot_metrics(input, output):
    matplotlib.use('Agg')
    ax = plt.subplot(111)
    fig, axs = plt.subplots(ncols=3, nrows=1, figsize=(10, 8))
    datasets = ["free_energy", "solid_fraction", "tip_position"]
    for metric in input:
        metric = Path(metric)
        with open(metric.parent / "params.json", "r") as f:
            params = json.load(f)
        df = pd.read_csv(metric)
        label = f"dx={params['dx']} dt={params['dt']}"
        for dataset, ax in zip(datasets, axs):
            df.plot("t", "tip_position", ax=ax,
                    # marker=".", linestyle="", markersize=1,
                    label=label)
    for dataset, ax in zip(datasets, axs):
        ax.set_ylabel(dataset)
    plt.savefig(output)
    