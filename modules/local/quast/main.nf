process QUAST {
    label 'process_medium'

    conda (params.enable_conda ? 'bioconda::quast=5.2.0' : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/quast:5.2.0--py39pl5321h2add14b_1' :
        'quay.io/biocontainers/quast:5.2.0--py39pl5321h2add14b_1' }"

    input:
    tuple val(meta), path(assembly)

    output:
    path "*"            , emit: results
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    """
    quast.py \\
        --output-dir $meta.id \\
        -r $PWD/$params.fasta \\
        --threads $task.cpus \\
        $assembly

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed 's/^.*QUAST v//; s/ .*\$//')
    END_VERSIONS
    """
}
