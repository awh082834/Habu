process UNZIP{
    tag "$meta.id"
    label "process_low"

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val(meta), path(zippedGFA)
    tuple val(meta), path(zippedASSEM) 
    tuple val(meta), path(longReads)

    output:
    tuple val(meta), path ('*.fa')  , emit: unzippedAssem
    tuple val(meta), path ('*.gfa')  , emit: unzippedGFA
    tuple val(meta), path ('*.fastq') , emit: unzippedReads
    script:
    """
    gzip -d $zippedGFA
    gzip -d $zippedASSEM
    gzip -d $longReads
    """
}