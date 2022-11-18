include { PLASMIDFINDER        } from '../../modules/nf-core/plasmidfinder/main'
include { PROKKA_PLAS              } from '../../modules/local/prokkaPlas/main'
include { AMRFINDERPLUS_UPDATE } from '../../modules/nf-core/amrfinderplus/update/main'
include { AMRFINDERPLUS_PLAS_RUN    } from '../../modules/local/amrfinderplusPlas/run/main'
include { PLASMIDPULLER        } from '../../modules/local/plasmid_puller'

workflow PLAS_ANALYSIS {
    take:
    medakaOut

    main:
    PLASMIDFINDER (medakaOut)
    PLASMIDPULLER (medakaOut, PLASMIDFINDER.out.tsv)
    AMRFINDERPLUS_UPDATE ()
    AMRFINDERPLUS_PLAS_RUN (PLASMIDPULLER.out.plasmids, AMRFINDERPLUS_UPDATE.out.db)
    PROKKA_PLAS (PLASMIDPULLER.out.plasmids, [], [])
}