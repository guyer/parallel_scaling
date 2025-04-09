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
