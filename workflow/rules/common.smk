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

def get_simulations(config):
    suites = []
    for name, suite in config["suites"].items():
        if suite is None:
            suite = {}

        tasks = suite.get("tasks", {})
        min_tasks = tasks.get("min", 1)
        max_tasks = tasks.get("max", 1)
        tasks_steps = tasks.get("steps", 1)
        tasks_base = tasks.get("base", 2)

        tasks = np.logspace(start=np.log(min_tasks) / np.log(tasks_base),
                            stop=np.log(max_tasks) / np.log(tasks_base),
                            num=tasks_steps,
                            base=tasks_base,
                            dtype=int)
        df = pd.DataFrame({"tasks": tasks})
        df["suite"] = name

        suites.append(df)

    benchmarks = pd.concat(suites)
    benchmarks["benchmark"] = config["benchmark"]
    benchmarks["dx"] = config["dx"]
    benchmarks["totaltime"] = config["totaltime"]
    benchmarks["hostname"] = platform.node()

    fipy_revs = pd.DataFrame(config["fipy_revs"], columns=["fipy_rev"])

    return benchmarks.join(fipy_revs, how="cross")

def get_mpi(wildcards):
    simulation = SIMULATIONS.loc[int(wildcards.id)]
    if simulation.tasks == 1:
        mpi = ""
    else:
        mpi = f"mpiexec -n {simulation['tasks']}"

    return mpi

def load_metrics(r):
    fname = f"results/fipy~{r.fipy_rev}/suite~{r.suite}/{r.name}/metrics.json"
    return pd.read_json(fname, typ='series')
