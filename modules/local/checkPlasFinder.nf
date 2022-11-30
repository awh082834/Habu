process CHECK_PLAS_FINDER {
    label = "process_low"

    input:
    tuple val (meta), path (plasTsv)

    output:
    val (proceed) , emit: checked
    tuple val (meta), path("*.txt"), emit: log, optional: true

    script:
    tsv = file(plasTsv)
    lines = tsv.readLines()
    if( lines.size() > 1){
        proceed = 1
    }
    else{
        proceed = 0
        new File('NoKnownPlasmid.txt').withWriter('utf-8'){
            writer -> 
            writer << 'No known plasmid was identified by PlasmidFinder.'
            writer << 'Please review the Bandage plot and characterize circular contigs independently.'
        }
    }
}