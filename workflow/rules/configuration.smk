import functools
import hashlib
import numpy as np
import pandas as pd
from pathlib import Path

DEFAULT = {
    'fipy_url': 'https://github.com/usnistgov/fipy.git',
    'fipy_rev': 'a5f233aa7',
    'replicate': 1,
    'Lx': 960,
    'dx': 1.,
    'dt': 0.15,
    't_max': 1500,
    'checkpoints': [0],
    'r0': 8,
    'view': False,
    'simulation': 'dendrite-1D',
    'task': 1,
    'suite': 'petsc',
    'study': 'scan_dx',
    'solver': None,
    'preconditioner': None
}

def get_dtype(value):
    dtype = value.get("dtype", "float")
    return {"float": float, "int": int}[dtype]

def get_space_parameters(value):
    min_val = value.get("start", 1)
    max_val = value.get("stop", 1)
    val_steps = value.get("num", 1)
    dtype = get_dtype(value)

    return (min_val, max_val, val_steps, dtype)

def get_linspace(value):
    (min_val, max_val, val_steps, dtype) = get_space_parameters(value)

    space = np.linspace(start=min_val,
                        stop=max_val,
                        num=val_steps,
                        dtype=dtype)

    return space

def get_logspace(value):
    (min_val, max_val, val_steps, dtype) = get_space_parameters(value)
    val_base = value.get("base", 2)

    space = np.logspace(start=np.log(min_val) / np.log(val_base),
                        stop=np.log(max_val) / np.log(val_base),
                        num=val_steps,
                        base=val_base,
                        dtype=dtype)

    return space

def get_space(key, value, no_expand=False):
    """Return numbers spaced
    If `value` is a list or tuple, return it.
    If `value` is a single value, return a list containing `value`.
    If `value` is a dictionary, interpret it as a space description:
        - `start`
        - `stop`
        - `num`
        - `base`, optional; if present, returns logspace
        - `dtype`, default `int`
    """
    if no_expand:
        space = [value]
    elif isinstance(value, dict):
        if "base" in value:
            space = get_logspace(value)
        else:
            space = get_linspace(value)
    elif not isinstance(value, (list, tuple)):
        space = [value]
    else:
        space = value

    return pd.DataFrame({key: space})

def replace_from_json(config, key, json_file):
    if config[key] == "all":
        config[key] = pd.read_json(json_file)[key].to_list()

def build_configurations_base(config):
    config = config.copy()
    config["replicate"] = list(range(config.get("replicate", 1)))

    path = Path(f"results/fipy~{config['fipy_rev']}/suite~{config['suite']}")
    replace_from_json(config, "solver",
                      path / "solvers.json")
    replace_from_json(config, "preconditioner",
                      path / "preconditioners.json")

    parameters = []
    for key, value in config.items():
        # don't expand checkpoints into separate simulations
        space = get_space(key, value,
                          no_expand=key in ["checkpoints"])
        parameters.append(space)

    return functools.reduce(lambda a, b: a.join(b, how="cross"), parameters)

def do_one(config, do_config, key, value_name, keys):
    config = config.copy()
    config.update(do_config)
    config[key] = value_name

    return expand_configurations(config, keys)

def expand_configurations(config, keys=[]):
    if not keys:
        return [config]

    config = config.copy()
    key = keys[0]
    value = config.pop(key)
    configs = []
    if isinstance(value, str):
        configs += do_one(config, {}, key, value, keys[1:])
    elif isinstance(value, dict):
        for value_name, value_config in value.items():
            configs += do_one(config, value_config, key, value_name, keys[1:])
    elif isinstance(value, (list, tuple)):
        for value_name in value:
            configs += do_one(config, {}, key, value_name, keys[1:])

    return configs

def build_configurations(config):
    updated = DEFAULT.copy()
    updated.update(config)
    configs = expand_configurations(updated,
                                    ["fipy_rev", "suite", "study"])

    dfs = []
    for config in configs:
        dfs.append(build_configurations_base(config))

    return pd.concat(dfs, ignore_index=True)

def hash_row(row):
    # adapted from https://stackoverflow.com/a/67438471/2019542
    #
    # note: hash() is not stable across Python sessions
    # https://stackoverflow.com/questions/27522626/hash-function-in-python-3-3-returns-different-results-between-sessions
    # We need to sort arguments so {'a': 1, 'b': 2} is
    # the same as {'b': 2, 'a': 1}
    encoded = row.sort_index().to_json().encode()
    dhash = hashlib.sha1(encoded, usedforsecurity=False)

    return dhash.hexdigest()

def get_simulations(config):
    df = build_configurations(config)

    df = df[~((df["solver"].isin(["LinearLUSolver", "LinearJORSolver"])
              & (df["preconditioner"] != "none")))]
    df = df[~(df["preconditioner"] == "MultilevelSolverSmootherPreconditioner")]

    df["index"] = df.apply(hash_row, axis=1)
    df.set_index("index", inplace=True)

    return df
