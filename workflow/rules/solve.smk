import json

rule solve:
    output:
        "results/{simulation}/fipy~{rev}/suite~{suite}/{id}/metrics.csv"
    input:
        simulation="workflow/scripts/{simulation}.py",
        params="results/{simulation}/fipy~{rev}/suite~{suite}/{id}/params.json"
    resources:
      mpi=get_mpi,
      tasks=lambda wildcards: int(SIMULATIONS.loc[wildcards.id, "task"])
    conda:
        "../workflow/envs/fipy~{rev}/suite~{suite}/environment.yml"
    log:
        "logs/{simulation}/fipy~{rev}/suite~{suite}/{id}/notebooks/simulation.log"
    benchmark:
        "benchmarks/{simulation}/fipy~{rev}/suite~{suite}/{id}/benchmark.tsv"
    shell:
        r"""
        FIPY_SOLVERS={wildcards.suite} \
            {resources.mpi} \
            python {input.simulation:q} {input.params:q} \
            > {output} \
            2> {log:q} \
            || touch {output:q}
        """

rule params:
    output:
        "results/{simulation}/fipy~{rev}/suite~{suite}/{id}/params.json"
    params:
        config=get_config_by_id,
    run:
        with open(output[0], "w") as f:
            json.dump(params.config, f)
