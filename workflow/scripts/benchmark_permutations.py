import platform
import numpy as np
import pandas as pd
import logging

def get_list_from_file(listf):
    with open(listf, 'r') as f:
        items = f.read().split()
    return items

logging.basicConfig(
    filename=snakemake.log[0],
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
)

try:
#     min_dx = snakemake.config["dx"].get("min", 0.001)
#     max_dx = snakemake.config["dx"].get("max", 0.1)
#     dx_steps = snakemake.config["dx"].get("steps", 6)
#     dxs = np.logspace(np.log10(min_dx), np.log10(max_dx),
#                       dx_steps, dtype=int)

    suites = []
    for name, suite in snakemake.config["suites"].items():
        min_rank = suite["rank"].get("min", 1)
        max_rank = suite["rank"].get("max", 1)
        rank_steps = suite["rank"].get("steps", 1)
        rank_base = suite["rank"].get("base", 2)
        ranks = np.logspace(start=np.log(min_rank) / np.log(rank_base),
                            stop=np.log(max_rank) / np.log(rank_base),
                            num=rank_steps,
                            base=rank_base,
                            dtype=int)
        df = pd.DataFrame({"rank": ranks})
        df["suite"] = name
        
        suites.append(df)

    df = pd.concat(suites)
    df["benchmark"] = snakemake.config["benchmark"]
    df["dx"] = snakemake.config["dx"]
    df["totaltime"] = snakemake.config["totaltime"]
    df["hostname"] = platform.node()
        
    df.to_csv(snakemake.output[0], index=False)
except Exception as e:
    logging.error(e, exc_info=True)
    raise e
