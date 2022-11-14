process SPLITLR{
    tag "$meta.id"
    label "process_low"

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path ('lr.fastq.gz')  , emit: longReads
    
    script:
    """
    mv ${reads[2]} lr.fastq.gz
    """
}