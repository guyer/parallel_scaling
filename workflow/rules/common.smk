import os
import platform
import pandas as pd
import numpy as np

def concat_csv(input, output, log):
    try:
        li = [pd.read_csv(fname, index_col=False) for fname in input]
        if li:
            df = pd.concat(li, ignore_index=True)
        else:
            df = pd.DataFrame()
        df.to_csv(output, index=False)
    except Exception as e:
        with open(log, 'w') as f:
            f.write(repr(e))
        raise e

def concat_json(input, output, log):
    try:
        li = [pd.read_json(fname) for fname in input]
        if li:
            df = pd.concat(li, ignore_index=True)
        else:
            df = pd.DataFrame()
        df.to_json(output)
    except Exception as e:
        with open(log, 'w') as f:
            f.write(repr(e))
        raise e

def get_permutation_ids(wildcards):
#     path = checkpoints.all_permutations.get(**wildcards).output[0]
    path = "config/all_permutations.csv"
    df = pd.read_csv(path)
    return df.index.map("{:07d}".format)

def get_benchmark(wildcards):
    benchmark = SIMULATIONS.loc[int(wildcards.id), 'benchmark']
    return f"workflow/scripts/{benchmark}.py"

# https://bioinformatics.stackexchange.com/questions/18248/pick-matching-entry-from-snakemake-config-table
# https://github.com/snakemake/snakemake/issues/1171#issuecomment-927242813
def get_config_by_id(wildcards):
    global config

    id_config = {}
    id_config.update(config)
    id_config.update(SIMULATIONS.loc[int(wildcards.id)].to_dict())
    return id_config

def get_logspace(config, key):
    values = config.get(key, {})
    min_val = values.get("min", 1)
    max_val = values.get("max", 1)
    val_steps = values.get("steps", 1)
    val_base = values.get("base", 2)

    space = np.logspace(start=np.log(min_val) / np.log(val_base),
                        stop=np.log(max_val) / np.log(val_base),
                        num=val_steps,
                        base=val_base,
                        dtype=int)

    return space

def get_simulations(config):
    suites = []
    for name, suite in config["suites"].items():
        if suite is None:
            suite = {}

        tasks = get_logspace(suite, "tasks")
        df = pd.DataFrame({"tasks": tasks})
        df["suite"] = name

        suites.append(df)

    nx = get_logspace(config, "nx")
    df = pd.DataFrame({"nx": nx})
    df["benchmark"] = config["benchmark"]
    df["totaltime"] = config["totaltime"]
    df["hostname"] = platform.node()

    fipy_revs = pd.DataFrame(config["fipy_revs"], columns=["fipy_rev"])

    df = df.join(fipy_revs, how="cross")
    df = df.join(pd.concat(suites), how="cross")

    df = pd.concat([df] * config.get("replicate", 1), ignore_index=True)

    return df

def get_mpi(wildcards):
    simulation = SIMULATIONS.loc[int(wildcards.id)]
    if simulation.tasks == 1:
        mpi = ""
    else:
        mpi = f"mpiexec -n {simulation['tasks']}"

    return mpi

def load_metrics(r):
    fname = f"results/fipy~{r.fipy_rev}/suite~{r.suite}/{r.name}/metrics.json"
    try:
        return pd.read_json(fname, typ='series')
    except ValueError:
        return pd.Series({
            "elapsed / s": np.nan,
            "etaerror2": np.nan,
            "etaerrorINF": np.nan,
            "solver": "",
            "preconditioner": ""
        })
