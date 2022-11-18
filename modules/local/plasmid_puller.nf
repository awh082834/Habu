process PLASMIDPULLER{
    label "process_low"

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    tuple val (meta), path (assem)
    tuple val (meta), path (plasTsv)

    output:
    tuple val (meta), path ('*.fa'), emit: plasmids

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
#!/usr/bin/env python
assemFile = "$assem"
plasTsv = "$plasTsv"
outfileGlob = "$prefix"

contigArray = []

try:
    with open(plasTsv, 'r') as infile:
        lines = infile.readlines()
        for line in lines:
            if 'Database' in line:
                continue
            else:
                temp = line.split("\t")
                if temp[4] not in contigArray:
                    contigArray.append(temp[4])
    infile.close()
except:
    print("PlasmidFinder File does not Exist")

try:
    with open(assemFile, 'r') as infile:
        fileNum = 1
        writeList = []
        headerIdx = 0
        lines = infile.readlines()
        for contig in contigArray:
            header = '>' + str(contig) + "\\n"
            if header in lines:
                headerIdx = lines.index(header)
                writeList.append(lines[headerIdx])
                writeList.append(lines[headerIdx+1])
                outfile = open(outfileGlob + "_plas" + str(fileNum) + ".fa", 'a')
                outfile.writelines(writeList)
                outfile.close()
            fileNum += 1
        infile.close()
except:
    print("Assembly File does not Exist")    
    """

}