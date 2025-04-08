import pandas as pd

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
    benchmark = SIMULATIONS.loc[wildcards.id, 'benchmark']
    return f"workflow/scripts/{benchmark}.py"

# https://bioinformatics.stackexchange.com/questions/18248/pick-matching-entry-from-snakemake-config-table
# https://github.com/snakemake/snakemake/issues/1171#issuecomment-927242813
def get_config_by_id(wildcards):
    global config

    id_config = {}
    # id_config.update(config)
    id_config.update(SIMULATIONS.loc[wildcards.id].to_dict())
    return id_config

def get_mpi(wildcards):
    simulation = SIMULATIONS.loc[wildcards.id]
    if simulation.task == 1:
        mpi = ""
    else:
        mpi = f"mpiexec -n {simulation['task']}"

    return mpi

def load_metrics(r):
    fname = f"results/fipy~{r.fipy_rev}/suite~{r.suite}/{r.name}/metrics.json"
    try:
        return pd.read_json(fname, typ='series')
    except ValueError:
        return pd.Series([])

def get_scan_simulations(wildcards):
    subset = SIMULATIONS[SIMULATIONS["simulation"] == wildcards.simulation]
    return expand("results/fipy~{rev}/suite~{suite}/{id}/metrics.csv",
                  zip,
                  rev=subset["fipy_rev"],
                  suite=subset["suite"],
                  id=subset.index)

def get_scan_benchmarks(wildcards):
    subset = SIMULATIONS[SIMULATIONS["simulation"] == wildcards.simulation]
    return expand("benchmarks/fipy~{rev}/suite~{suite}/{id}/benchmark-dendrite1D.tsv",
                  zip,
                  rev=subset["fipy_rev"],
                  suite=subset["suite"],
                  id=subset.index)
