import json

rule solve:
    output:
        "results/fipy~{rev}/suite~{suite}/{id}/metrics.json"
    input:
        env="results/fipy~{rev}/suite~{suite}/environment.yml",
        benchmark=get_benchmark,
    params:
        config=get_config_by_id,
    resources:
      mpi=get_mpi,
      tasks=lambda wildcards: int(SIMULATIONS["all"].loc[wildcards.id, "tasks"])
    conda:
        "../../results/fipy~{rev}/suite~{suite}/environment.yml"
    log:
        "logs/fipy~{rev}/suite~{suite}/{id}/notebooks/benchmark.log"
    benchmark:
        "benchmarks/fipy~{rev}/suite~{suite}/{id}/benchmark.tsv"
    shell:
        r"""
        FIPY_SOLVERS={wildcards.suite} \
            {resources.mpi} \
            python {input.benchmark:q} \
            --solver=LinearGMRESSolver \
            --preconditioner=JacobiPreconditioner \
            --totaltime={params.config[totaltime]} \
            --nx={params.config[nx]} \
            > {output} \
            2> {log:q} \
            || touch {output:q}
        """

rule dendrite_1D:
    output:
        "results/fipy~{rev}/suite~{suite}/{id}/metrics.csv"
    input:
        benchmark="workflow/scripts/dendrite-1D.py",
        params="results/fipy~{rev}/suite~{suite}/{id}/params.json"
    resources:
      mpi=get_mpi,
      tasks=lambda wildcards: int(SIMULATIONS["all"].loc[wildcards.id, "tasks"])
    conda:
        "../../results/fipy~{rev}/suite~{suite}/environment.yml"
    log:
        "logs/fipy~{rev}/suite~{suite}/{id}/notebooks/benchmark.log"
    benchmark:
        "benchmarks/fipy~{rev}/suite~{suite}/{id}/benchmark.tsv"
    shell:
        r"""
        FIPY_SOLVERS={wildcards.suite} \
            {resources.mpi} \
            python {input.benchmark:q} {input.params:q} {output:q} \
            > {output} \
            2> {log:q}
        """

rule dendrite_1D_params:
    output:
        "results/fipy~{rev}/suite~{suite}/{id}/params.json"
    params:
        config=get_config_by_id,
    run:
        with open(output[0], "w") as f:
            json.dump(params.config, f)

rule ipynb2py:
    output:
        "workflow/scripts/{notebook}.py"
    input:
        "workflow/notebooks/{notebook}.py.ipynb"
    conda:
        "../envs/snakemake.yml"
    log:
        stdout="workflow/scripts/{notebook}.stdout",
        stderr="workflow/scripts/{notebook}.stderr"
    shell:
        r"""
        jupyter nbconvert {input:q} --to python \
            --output-dir=workflow/scripts/ \
            --output {wildcards.notebook:q}.py \
            > {log.stdout:q} 2> {log.stderr:q}
        """
