rule plot_permutations:
    output:
        total="results/plots/fipy~{rev}/{benchmark}/total.png",
        prepare="results/plots/fipy~{rev}/{benchmark}/prepare.png",
        solve="results/plots/fipy~{rev}/{benchmark}/solve.png",
        plots=report(
            directory("results/plots/fipy~{rev}/{benchmark}"),
            patterns=["{name}.png"],
            category="{rev}",
            subcategory="{benchmark}",
            labels={
                "benchmark": "{benchmark}",
                "name": "{name}"
            }
        )
    input:
        "results/total_times.json"
    log:
        "logs/{benchmark}/plot_permutations_{rev}.log"
    conda:
        "../envs/snakemake.yml"
    script:
        "../scripts/plot_permutations.py"

rule append_time_to_permutations:
    output:
        json="results/all_permutations_timed.json"
    input:
        csv="config/all_permutations.csv"
    run:
        import numpy as np

        df = pd.read_csv(input["csv"])

        def get_elapsed(row):
            benchmark = f"benchmarks/fipy~{row['fipy_rev']}/suite~{row['suite']}/benchmark-{row['id']}.tsv"
            benchmark = Path(benchmark)
            if benchmark.exists():
                return pd.read_table(benchmark).iloc[0]["s"]
            else:
                return np.nan

        # merge elapsed time with permutations
        df["elapsed_seconds"] = df.apply(get_elapsed, axis=1)

        # make digestible by plot_all()
        df["converged"] = True
        df = df.rename(columns={
                "suite": "package.solver",
                "solver": "solver_class"
            })

        df.to_json(output["json"])

rule total_times:
    localrule: True
    output:
        "results/total_times.json"
    input:
        all="results/all.json",
    log:
        "logs/total_times.log"
    conda:
        "../envs/snakemake.yml"
    script:
        "../scripts/extract_total_times.py"
