import sys

assemFile = sys.argv[1]
plasTsv = sys.argv[2]
outfileGlob = sys.argv[3]

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
            header = '>' + str(contig) + "\n"
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

                