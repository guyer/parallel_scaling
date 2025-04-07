import hashlib
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

def concat_tsv(input, output, log):
    try:
        li = [pd.read_csv(fname, delimiter="\t", index_col=False) for fname in input]
        if li:
            df = pd.concat(li, ignore_index=True)
        else:
            df = pd.DataFrame()
        df.to_csv(output, index=False)
    except Exception as e:
        with open(log, 'w') as f:
            # f.write(repr(e))
            f.write(f"{input=}")
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
    benchmark = SIMULATIONS["all"].loc[wildcards.id, 'benchmark']
    return f"workflow/scripts/{benchmark}.py"

# https://bioinformatics.stackexchange.com/questions/18248/pick-matching-entry-from-snakemake-config-table
# https://github.com/snakemake/snakemake/issues/1171#issuecomment-927242813
def get_config_by_id(wildcards):
    global config

    id_config = {}
    # id_config.update(config)
    id_config.update(SIMULATIONS["all"].loc[wildcards.id].to_dict())
    return id_config

def get_logspace(config, key, dtype=int):
    values = config.get(key, {})
    if isinstance(values, dict):
        min_val = values.get("min", 1)
        max_val = values.get("max", 1)
        val_steps = values.get("steps", 1)
        val_base = values.get("base", 2)

        space = np.logspace(start=np.log(min_val) / np.log(val_base),
                            stop=np.log(max_val) / np.log(val_base),
                            num=val_steps,
                            base=val_base,
                            dtype=dtype)
    else:
        space = np.array([values])

    return space

def build_configurations(config):
    suites = []
    for name, suite in config.get("suites", {}).items():
        if suite is None:
            suite = {}

        tasks = get_logspace(suite, "tasks")
        df = pd.DataFrame({"tasks": tasks})
        df["suite"] = name

        suites.append(df)

    dx = get_logspace(config, "dx", dtype=float)
    df = pd.DataFrame({"dx": dx})
    dt = get_logspace(config, "dt", dtype=float)
    df = df.join(pd.DataFrame({"dt": dt}), how="cross")

    df["benchmark"] = config["benchmark"]
    df["Lx"] = config["Lx"]
    df["t_max"] = config["t_max"]
    df["r0"] = config["r0"]
    df["hostname"] = platform.node()
    df["view"] = config["view"]

    fipy_revs = pd.DataFrame(config["fipy_revs"], columns=["fipy_rev"])

    df = df.join(fipy_revs, how="cross")
    df = df.join(pd.concat(suites), how="cross")

    df = pd.concat([df] * config.get("replicate", 1), ignore_index=True)

    return df

def hash_row(row):
    # adapted from https://stackoverflow.com/a/67438471/2019542
    #
    # note: hash() is not stable across Python sessions
    # https://stackoverflow.com/questions/27522626/hash-function-in-python-3-3-returns-different-results-between-sessions
    dhash = hashlib.md5()
    # We need to sort arguments so {'a': 1, 'b': 2} is
    # the same as {'b': 2, 'a': 1}
    encoded = row.sort_index().to_json().encode()
    dhash.update(encoded)

    return dhash.hexdigest()

def get_simulations(config):
    df = build_configurations(config)

    permutation_file = Path("config/fipy_permutations.csv")
    if (config["solver"] == "all") & permutation_file.exists():
        permutations = pd.read_csv(permutation_file)

        df = df.merge(permutations, on=("fipy_rev", "suite"), how="outer")
    else:
        if type(config["solver"]) not in [list, tuple]:
            config["solver"] = [config["solver"]]
        if type(config["preconditioner"]) not in [list, tuple]:
            config["preconditioner"] = [config["preconditioner"]]

        solvers = pd.DataFrame({"solver": config["solver"]})
        preconditioners = pd.DataFrame({"preconditioner": config["preconditioner"]})
        permutations = solvers.join(preconditioners, how="cross")
        # it makes no sense to precondition LU
        permutations = permutations.query("(solver != 'LinearLUSolver')"
                                          "| (preconditioner == 'none')")
        df = df.join(permutations, how="cross")

    df = df[~((df["solver"].isin(["LinearLUSolver", "LinearJORSolver"])
              & (df["preconditioner"] != "none")))]
    df = df[~(df["preconditioner"] == "MultilevelSolverSmootherPreconditioner")]

    df["index"] = df.apply(hash_row, axis=1)
    df.set_index("index", inplace=True)

    return df

def get_configurations(config):
    default = {
        "solver": None,
        "preconditioner": None
    }
    default.update(config)
    del default["simulation"]

    configurations = {}
    for name, simulation in config["simulation"].items():
        updated = default.copy()
        if simulation is not None:
            updated.update(simulation)
        configurations[name] = updated

    return configurations

def get_mpi(wildcards):
    simulation = SIMULATIONS["all"].loc[wildcards.id]
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
        return pd.Series([])

def get_scan_simulations(wildcards):
    return expand("results/fipy~{rev}/suite~{suite}/{id}/metrics.csv",
                  zip,
                  rev=SIMULATIONS[wildcards.scan]["fipy_rev"],
                  suite=SIMULATIONS[wildcards.scan]["suite"],
                  id=SIMULATIONS[wildcards.scan].index)

def get_scan_benchmarks(wildcards):
    return expand("benchmarks/fipy~{rev}/suite~{suite}/{id}/benchmark-dendrite1D.tsv",
                  zip,
                  rev=SIMULATIONS[wildcards.scan]["fipy_rev"],
                  suite=SIMULATIONS[wildcards.scan]["suite"],
                  id=SIMULATIONS[wildcards.scan].index)
