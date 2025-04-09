rule render_conda_template:
    localrule: True
    output:
        "workflow/envs/fipy~{rev}/suite~{suite}/environment.yml"
    input:
        template="workflow/envs/benchmark_{suite}.yml",
    log:
        "logs/fipy~{rev}/suite~{suite}/render_conda_template.log"
    template_engine:
        "yte"
