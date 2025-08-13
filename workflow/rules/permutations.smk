include: "common.smk"

rule benchmark_permutations:
    output:
        "config/benchmark_permutations.csv"
    conda:
        "../envs/snakemake.yml"
    log:
        "logs/benchmark_permutations.log"
    script:
        "../scripts/benchmark_permutations.py"

rule fipy_permutations:
    output:
        "config/fipy_permutations.csv"
    input:
        expand("config/fipy~{rev}/suite_permutations.csv",
               rev=config["fipy_revs"])
    log:
        "logs/all_permutations.log"
    run:
        concat_csv(input, output[0], log[0])

rule suite_permutations:
    output:
        "config/fipy~{rev}/suite_permutations.csv"
    input:
        expand("config/fipy~{{rev}}/suite~{suite}/permutations.csv",
               suite=config["suites"])
    log:
        "logs/fipy~{rev}/suite_permutations.csv"
    run:
        concat_csv(input, output[0], log[0])

rule solver_preconditioner_permutations:
    output:
        "config/fipy~{rev}/suite~{suite}/permutations.csv"
    input:
        solvers="results/fipy~{rev}/suite~{suite}/solvers.json",
        preconditioners="results/fipy~{rev}/suite~{suite}/preconditioners.json"
    log:
        "logs/fipy~{rev}/suite~{suite}/solver_preconditioner_permutations.log"
    run:
        solvers = pd.read_json(input["solvers"])
        preconditioners = pd.read_json(input["preconditioners"])

        permutations = solvers.join(preconditioners, how="cross")
        # it makes no sense to precondition LU
        permutations = permutations.query("(solver != 'LinearLUSolver')"
                                          "| (preconditioner == 'none')")

        permutations["suite"] = wildcards["suite"]
        permutations["fipy_rev"] = wildcards["rev"]
        suite = config["suites"][wildcards["suite"]]
        if suite is None:
            suite = {}
        tasks = get_logspace(suite, "tasks")
        tasks = pd.DataFrame({"tasks": tasks})
        permutations = permutations.join(tasks, how="cross")
        permutations.to_csv(output[0], index=False)

rule get_solvers_preconditioners:
    output:
        solvers="results/fipy~{rev}/suite~{suite}/solvers.json",
        preconditioners="results/fipy~{rev}/suite~{suite}/preconditioners.json"
    conda:
        "../../results/fipy~{rev}/suite~{suite}/environment.yml"
    log:
        "logs/fipy~{rev}/suite~{suite}/get_solvers_preconditioners.log"
    shell:
        "FIPY_SOLVERS={wildcards.suite}"
        " python workflow/scripts/get_solvers_preconditioners.py"
        " {output.solvers} {output.preconditioners}"
        " 2> {log}"
