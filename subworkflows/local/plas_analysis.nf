//include { PLASMIDFINDER             } from '../../modules/nf-core/plasmidfinder/main'
include { MOBSUITE_RECON            } from '../../modules/nf-core/mobsuite/recon/main'
include { PROKKA_PLAS               } from '../../modules/local/prokkaPlas/main'
include { AMRFINDERPLUS_UPDATE      } from '../../modules/nf-core/amrfinderplus/update/main'
include { AMRFINDERPLUS_PLAS_RUN    } from '../../modules/local/amrfinderplusPlas/run/main'
//include { PLASMIDPULLER             } from '../../modules/local/plasmid_puller'
//include { CHECK_PLAS_FINDER         } from '../../modules/local/checkPlasFinder'

workflow PLAS_ANALYSIS {

    take:
    unicyclerOut

    main:
    AMRFINDERPLUS_UPDATE()
    MOBSUITE_RECON(unicyclerOut)
    MOBSUITE_RECON.out.plasmids.view()
    AMRFINDERPLUS_PLAS_RUN(MOBSUITE_RECON.out.plasmids,AMRFINDERPLUS_UPDATE.out.db)
    PROKKA_PLAS (MOBSUITE_RECON.out.plasmids,[],[])
}