/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowHabu.initialise(params, log)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { QUAST                            } from '../modules/local/quast/main'
include { SPLITLR                          } from '../modules/local/splitLR'
include { UNZIP                            } from '../modules/local/unzip'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                           } from '../modules/nf-core/fastqc/main'
include { MULTIQC                          } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS      } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { AMRFINDERPLUS_UPDATE             } from '../modules/nf-core/amrfinderplus/update/main'
include { NANOPLOT                         } from '../modules/nf-core/nanoplot/main'

//Trim and Filter
include { TRIMGALORE                       } from '../modules/nf-core/trimgalore/main'
include { PORECHOP_PORECHOP                } from '../modules/nf-core/porechop//porechop/main'
include { FILTLONG                         } from '../modules/nf-core/filtlong/main'

//Assembly
include { UNICYCLER                        } from '../modules/nf-core/unicycler/main'
include { MEDAKA                           } from '../modules/nf-core/medaka/main'

//Post Assembly Analysis
include { PROKKA                           } from '../modules/nf-core/prokka/main'
include { AMRFINDERPLUS_RUN                } from '../modules/nf-core/amrfinderplus/run/main'
include { BANDAGE_IMAGE                    } from '../modules/nf-core/bandage/image/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow HABU {

    ch_versions = Channel.empty()
    
    //Channel used for input of Unicycler
    ch_hybridReads = Channel.empty()

    //
    //SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (ch_input)
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    //
    //MODULE: Run Update AMRFinderPlus
    //
    AMRFINDERPLUS_UPDATE()
    ch_versions = ch_versions.mix(AMRFINDERPLUS_UPDATE.out.versions)

    //
    //MODULE: Run FastQC
    //
    FASTQC (INPUT_CHECK.out.reads)
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    //Isolates the long read reads
    //
    SPLITLR (INPUT_CHECK.out.reads)

    //
    //MODULE: Run NanoPlot
    //
    NANOPLOT (SPLITLR.out.longReads)
    ch_versions = ch_versions.mix(NANOPLOT.out.versions.first())

    //
    //MODULE: Run Trimgalore
    //
    TRIMGALORE (INPUT_CHECK.out.reads)
    ch_versions = ch_versions.mix(TRIMGALORE.out.versions.first())

    //
    //MODULE: Run PoreChop
    //
    PORECHOP_PORECHOP (SPLITLR.out.longReads)
    ch_versions = ch_versions.mix(PORECHOP_PORECHOP.out.versions.first())

    //
    //MODULES: Run FiltLong
    //
    FILTLONG (TRIMGALORE.out.reads.join(PORECHOP_PORECHOP.out.reads))
    ch_versions = ch_versions.mix(FILTLONG.out.versions.first())

    //
    //Combine filtered long reads into trimmed short reads channel for input to UniCycler
    //
    ch_hybridReads = TRIMGALORE.out.reads.join(FILTLONG.out.reads)

    //
    //MODULES: Run UniCycler
    //
    UNICYCLER (ch_hybridReads)
    ch_versions = ch_versions.mix(UNICYCLER.out.versions.first())

    //
    //Unzip files that require non .gz
    //
    UNZIP(UNICYCLER.out.gfa, UNICYCLER.out.scaffolds, SPLITLR.out.longReads)
    
    //
    //MODULES: Medaka Polishing
    //
    MEDAKA (UNZIP.out.unzippedReads.join(UNZIP.out.unzippedAssem))
    ch_versions = ch_versions.mix(MEDAKA.out.versions.first())

    //
    //MODULES: Run QUAST
    //
    QUAST (MEDAKA.out.assembly)
    ch_versions = ch_versions.mix(QUAST.out.versions.first())

    //
    //MODULES: Run Bandage
    //
    BANDAGE_IMAGE(UNZIP.out.unzippedGFA)
    ch_versions = ch_versions.mix(BANDAGE_IMAGE.out.versions.first())

    //
    //MODULES: Run Prokka
    //
    PROKKA (MEDAKA.out.assembly, [],[])
    ch_versions = ch_versions.mix(PROKKA.out.versions.first())

    //
    //MODULES: Run AmrFinderPlus
    //
    AMRFINDERPLUS_RUN (MEDAKA.out.assembly,AMRFINDERPLUS_UPDATE.out.db)
    ch_versions = ch_versions.mix(AMRFINDERPLUS_RUN.out.versions.first())

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowHabu.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowHabu.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.collect().ifEmpty([]),
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_multiqc_logo.collect().ifEmpty([])
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
