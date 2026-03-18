version 1.0

import "subworkflows/annotate_variants.wdl" as VariantAnnotation


workflow ctat_mutations_DV {
    input {
        String sample_id

        # different entry points based on inputs
        File? fastq_left
        File? fastq_right
        File? bam
        File? bai
        File? vcf
        File? vcf_index
        
        File? extra_fasta
        Boolean merge_extra_fasta = true

        # resources - all resources derive from the ctat genome lib.
        File ref_fasta
        File ref_fasta_index
        # for long reads
        Boolean is_long_reads = false
        File? mm2_genome_idx
        File? mm2_splice_bed

        # annotation resources
        File? db_snp_vcf
        File? db_snp_vcf_index

        File? gnomad_vcf
        File? gnomad_vcf_index

        File? rna_editing_vcf
        File? rna_editing_vcf_index

        File? repeat_mask_bed

        File? ref_splice_adj_regions_bed

        File? cosmic_vcf
        File? cosmic_vcf_index

        File? ref_bed

        File? cravat_lib_tar_gz
        String? cravat_lib_dir

        String? genome_version

        File? star_reference
        String? star_reference_dir
        String star_limitBAMsortRAM = "30000000000"  # doesnt like large integer value as int type in wdl... so using string to make it work. 

        File? intervals
      
        Boolean annotate_variants = true


        Boolean filter_variants = true
        Boolean filter_cancer_variants = true
		
        Boolean variant_ready_bam = false
        Boolean filter_ready_vcf = false

        Boolean mark_duplicates = true
        Boolean add_read_groups = false

        Int variant_filtration_cpu = 1
        Int variant_annotation_cpu = 5

        Boolean singlecell_mode = false
        String cell_barcode_bam_tag = "CB"
        String umi_bam_tag = "XM"

        Boolean normalize_bam = true
        Int normalize_max_cov_level = 1000

        # DeepVariant configuration
        # Using v1.10.0 with run_deepvariant wrapper (handles make_examples/call_variants/postprocess_variants internally)
        Boolean deepvariant_use_gpu = false
        String deepvariant_docker = "google/deepvariant:1.10.0"
        String deepvariant_docker_gpu = "google/deepvariant:1.10.0-gpu"
        Int deepvariant_shards = 18
        Boolean output_gvcf = false
        Int deepvariant_min_gq = 18
        Int deepvariant_min_qual = 20
        Int deepvariant_min_dp = 5

        # annotation options
        Boolean incl_snpEff = true
        Boolean incl_dbsnp = true
        Boolean incl_gnomad = true
        Boolean incl_rna_editing = true
        Boolean incl_repeats = true
        Boolean incl_homopolymers = true
        Boolean incl_cravat = false  # Disabled due to SQLite locking issues with read-only genome lib mount
        Boolean incl_splice_dist = true
        Boolean incl_cosmic = true


        Float star_extra_disk_space = 30
        Float star_fastq_disk_space_multiplier = 10
        Boolean star_use_ssd = false
        Int star_cpu = 12
        Float star_memory = 43
        Boolean output_unmapped_reads = false

        Int preemptible = 2
        String docker = "trinityctat/ctat_mutations_dv:latest"
        String plugins_path = "/usr/local/src/ctat-mutations/plugins"
        String scripts_path = "/usr/local/src/ctat-mutations/src"

        Float mark_duplicates_memory = 16
        Float split_n_cigar_reads_memory = 32

        Float filter_memory = 10
    }

    Boolean vcf_input = defined(vcf)

    parameter_meta {

        fastq_left:{help:"One of the two paired RNAseq samples"}
        fastq_right:{help:"One of the two paired RNAseq samples"}
        bam:{help:"Previously aligned bam file."}
        bai:{help:"Previously aligned bam index file"}
        vcf:{help:"Previously generated vcf file to annotate and filter."}
        sample_id:{help:"Sample id"}

        # resources
        ref_fasta:{help:"Path to the reference genome to use in the analysis pipeline."}
        ref_fasta_index:{help:"Index for ref_fasta"}

        intervals:{help:"Intervals file to restrict variant calling to. (eg. exome target list file)"}
        
        extra_fasta:{help:"Extra genome to use in alignment and variant calling."}
        merge_extra_fasta:{help:"Whether to merge extra genome fasta to use in variant calling. Set to false when extra fasta is already included in primary fasta, but you want to process the reads from extra_fasta differently."}

        db_snp_vcf:{help:"dbSNP VCF file for the reference genome."}
        db_snp_vcf_index:{help:"dbSNP vcf index"}

        gnomad_vcf:{help:"gnomad vcf file w/ allele frequencies"}
        gnomad_vcf_index:{help:"gnomad VCF index"}

        rna_editing_vcf:{help:"RNA editing VCF file"}
        rna_editing_vcf_index:{help:"RNA editing VCF index"}

        cosmic_vcf:{help:"Coding Cosmic Mutation VCF annotated with Phenotype Information"}
        cosmic_vcf_index:{help:"COSMIC VCF index"}

        repeat_mask_bed:{help:"bed file containing repetive element (repeatmasker) annotations (from UCSC genome browser download)"}

        ref_splice_adj_regions_bed:{help:"For annotating exon splice proximity"}

        ref_bed:{help:"Reference gene annotation bed file for IGV cancer mutation report (refGene.sort.bed.gz)"}
        cravat_lib_tar_gz:{help:"CRAVAT resource archive"}
        cravat_lib_dir:{help:"CRAVAT resource directory (for non-Terra use)"}

        star_reference:{help:"STAR index archive"}
        star_reference_dir:{help:"STAR directory (for non-Terra use)"}
        star_limitBAMsortRAM:{help:"setting for STAR limitBAMsortRAM parameter"}
      
        genome_version:{help:"Genome version for annotating variants using Cravat and SnpEff", choices:["hg19", "hg38"]}

        add_read_groups : {help:"Whether to add read groups and sort the bam. Not required for DeepVariant but automatically enabled when mark_duplicates=true (since Picard MarkDuplicates requires RG tags). Default: false."}
        mark_duplicates : {help:"Whether to mark duplicates"}
        filter_cancer_variants:{help:"Whether to generate cancer VCF file"}
        annotate_variants:{help:"Whether to annotate the vcf file"}
        filter_variants:{help:"Whether to filter VCF file"}

        deepvariant_use_gpu:{help:"Use GPU acceleration for DeepVariant (requires GPU-enabled machine on Terra)"}
        deepvariant_shards:{help:"Number of shards for DeepVariant parallelization"}
        output_gvcf:{help:"Output gVCF file in addition to VCF"}
        deepvariant_min_gq:{help:"Minimum genotype quality (GQ) for DeepVariant filtering. Recommended: 18 for high precision."}
        deepvariant_min_qual:{help:"Minimum QUAL score for DeepVariant filtering"}
        deepvariant_min_dp:{help:"Minimum depth (DP) for DeepVariant filtering"}

        star_cpu:{help:"STAR aligner number of CPUs"}
        star_memory:{help:"STAR aligner memory"}
        output_unmapped_reads:{help:"Whether to output unmapped reads from STAR"}

        variant_filtration_cpu:{help:"Number of CPUs for variant filtration task"}
        variant_annotation_cpu:{help:"Number of CPUs for variant annotation task"}
        normalize_max_cov_level:{help:"Maximum per-strand coverage level used during BAM normalization"}

        plugins_path:{help:"Path to plugins"}
        scripts_path:{help:"Path to scripts"}

        docker:{help:"Docker or singularity image"}
    }

    if(!vcf_input && !defined(bam)) {
        
        if (is_long_reads) {
            if (defined(mm2_genome_idx) || defined(mm2_splice_bed)) {
                call Minimap2_align as mm2 {
                  input:
                    sample_id=sample_id,
                    mm2_genome_idx = mm2_genome_idx,
                    mm2_splice_bed = mm2_splice_bed,
                    reads = fastq_left,
                    
                    extra_disk_space = star_extra_disk_space,
                    fastq_disk_space_multiplier = star_fastq_disk_space_multiplier,
                    memory = star_memory,
                    use_ssd = star_use_ssd,
                    cpu = star_cpu,
                    docker = docker,
                    preemptible = preemptible
                }  
           }
        }
        
        if (! is_long_reads) {
          if (defined(star_reference_dir) || defined(star_reference)) {
              call StarAlign {
                input:
                    star_reference = star_reference,
                    star_reference_dir = star_reference_dir,
                    fastq1 = fastq_left,
                    fastq2 = fastq_right,
                    output_unmapped_reads = output_unmapped_reads,
                    genomeFastaFiles=extra_fasta,
                    STAR_limitBAMsortRAM=star_limitBAMsortRAM,
                    base_name = sample_id + '.star',
                    extra_disk_space = star_extra_disk_space,
                    fastq_disk_space_multiplier = star_fastq_disk_space_multiplier,
                    memory = star_memory,
                    use_ssd = star_use_ssd,
                    cpu = star_cpu,
                    docker = docker,
                    preemptible = preemptible
               }
         }
            
       }

    }

    if (normalize_bam && !variant_ready_bam) {

        call NormalizeBam {
            input:
            input_bam = select_first([StarAlign.bam, mm2.bam, bam]),
            max_coverage = normalize_max_cov_level,
            use_bamsifter = !is_long_reads,
            scripts_path = scripts_path,
            docker = docker,
            preemptible = preemptible
        }
    }

    # AddOrReplaceReadGroups: Not needed for DeepVariant, but required for MarkDuplicates
    # Run if explicitly requested OR if mark_duplicates is enabled (since Picard MarkDuplicates requires RG tags)
    if(!vcf_input && !variant_ready_bam && (add_read_groups || (mark_duplicates && !is_long_reads))) {
        call AddOrReplaceReadGroups {
            input:
                input_bam = select_first([NormalizeBam.output_bam, StarAlign.bam, mm2.bam, bam]),
                sample_id = sample_id,
                base_name = sample_id + '.sorted',
                sequencing_platform = "ILLUMINA",
                docker = docker,
                preemptible = preemptible
        }
    }

    if(!vcf_input && !variant_ready_bam && mark_duplicates && !is_long_reads ) {
        call MarkDuplicates {
            input:
                input_bam = select_first([AddOrReplaceReadGroups.bam, NormalizeBam.output_bam, StarAlign.bam, mm2.bam, bam]),
                base_name = sample_id + ".dedupped",
                memory = mark_duplicates_memory,
                docker = docker,
                preemptible = preemptible
        }
    }
    
    if(!vcf_input && !variant_ready_bam && defined(extra_fasta) && merge_extra_fasta) {
        call MergeFastas {
            input:
                name = "combined",
                ref_fasta = ref_fasta,
                extra_fasta = extra_fasta,
                docker = docker,
                preemptible = preemptible
        }
    }
    
    File fasta_index = select_first([MergeFastas.fasta_index, ref_fasta_index])


    if( (!vcf_input) && (!variant_ready_bam) ) {

        # For PacBio long reads: use custom SplitNCigarLongReads + flagCorrection
        # For Illumina: skip SplitNCigarReads (DeepVariant handles internally with split_skip_reads=true)
        if (is_long_reads) {
            call SplitNCigarLongReads {
                input:
                input_bam = select_first([MarkDuplicates.bam, NormalizeBam.output_bam, mm2.bam, bam]),
                input_bam_index = select_first([MarkDuplicates.bai, NormalizeBam.output_bai, mm2.bai, bai]),
                cell_barcode_bam_tag = cell_barcode_bam_tag,
                umi_bam_tag = umi_bam_tag,
                scripts_path = scripts_path,
                memory = split_n_cigar_reads_memory,
                docker = docker,
                preemptible = preemptible
            }

            call flagCorrection {
                input:
                    input_bam = SplitNCigarLongReads.bam,
                    input_bam_index = SplitNCigarLongReads.bai,
                    base_name = sample_id + ".flagCorrected",
                    docker = docker,
                    preemptible = preemptible
            }
        }
    }

    if(!vcf_input && !variant_ready_bam && defined(extra_fasta)) {
        call CreateFastaIndex {
            input:
                input_fasta = extra_fasta,
                docker = docker,
                preemptible = preemptible
        }

        call SplitReads {
                input:
                    input_bam = select_first([SplitNCigarLongReads.bam, MarkDuplicates.bam, NormalizeBam.output_bam, StarAlign.bam, mm2.bam]),
                    input_bam_index = select_first([SplitNCigarLongReads.bai, MarkDuplicates.bai, NormalizeBam.output_bai, StarAlign.bai, mm2.bai]),
                    extra_name = sample_id + '_' + basename(basename(select_first([extra_fasta]), ".fa"), ".fasta"),
                    ref_name = basename(basename(ref_fasta, ".fa"), ".fasta"),
                    extra_fasta_index = CreateFastaIndex.fasta_index,
                    ref_fasta_index = ref_fasta_index,
                docker = docker,
                preemptible = preemptible
        }
        if(SplitReads.extra_bam_number_of_reads > 0) {
            # DeepVariant for extra_fasta reads
            if (!deepvariant_use_gpu) {
                call DeepVariant_cpu as DeepVariant_Extra_cpu {
                    input:
                        input_bam = SplitReads.extra_bam,
                        input_bam_index = SplitReads.extra_bai,
                        ref_fasta = CreateFastaIndex.fasta,
                        ref_fasta_index = CreateFastaIndex.fasta_index,
                        sample_name = sample_id + '_' + basename(basename(select_first([extra_fasta]), ".fa"), ".fasta"),
                        is_long_reads = is_long_reads,
                        output_gvcf = output_gvcf,
                        intervals = intervals,
                        num_shards = deepvariant_shards,
                        docker = deepvariant_docker,
                        preemptible = preemptible
                }
            }
            if (deepvariant_use_gpu) {
                call DeepVariant_gpu as DeepVariant_Extra_gpu {
                    input:
                        input_bam = SplitReads.extra_bam,
                        input_bam_index = SplitReads.extra_bai,
                        ref_fasta = CreateFastaIndex.fasta,
                        ref_fasta_index = CreateFastaIndex.fasta_index,
                        sample_name = sample_id + '_' + basename(basename(select_first([extra_fasta]), ".fa"), ".fasta"),
                        is_long_reads = is_long_reads,
                        output_gvcf = output_gvcf,
                        intervals = intervals,
                        num_shards = deepvariant_shards,
                        docker = deepvariant_docker_gpu,
                        preemptible = preemptible
                }
            }
            File extra_dv_vcf = select_first([DeepVariant_Extra_gpu.vcf, DeepVariant_Extra_cpu.vcf])
        }
    }


    if(!vcf_input) {

        # Determine BAM for variant calling based on read type and preprocessing
        # For Illumina: MarkDuplicates -> DeepVariant (no SplitNCigarReads needed)
        # For PacBio: SplitNCigarLongReads -> flagCorrection -> DeepVariant
        File bam_for_variant_calls = select_first([SplitReads.ref_bam, flagCorrection.bam, SplitNCigarLongReads.bam, MarkDuplicates.bam, NormalizeBam.output_bam, StarAlign.bam, mm2.bam, bam])
        File bai_for_variant_calls = select_first([SplitReads.ref_bai, flagCorrection.bai, SplitNCigarLongReads.bai, MarkDuplicates.bai, NormalizeBam.output_bai, StarAlign.bai, mm2.bai, bai])

        # DeepVariant variant calling (run_deepvariant handles sharding internally)
        if (!deepvariant_use_gpu) {
            call DeepVariant_cpu {
                input:
                    input_bam = bam_for_variant_calls,
                    input_bam_index = bai_for_variant_calls,
                    ref_fasta = ref_fasta,
                    ref_fasta_index = ref_fasta_index,
                    sample_name = sample_id,
                    is_long_reads = is_long_reads,
                    output_gvcf = output_gvcf,
                    intervals = intervals,
                    num_shards = deepvariant_shards,
                    docker = deepvariant_docker,
                    preemptible = preemptible
            }
        }
        if (deepvariant_use_gpu) {
            call DeepVariant_gpu {
                input:
                    input_bam = bam_for_variant_calls,
                    input_bam_index = bai_for_variant_calls,
                    ref_fasta = ref_fasta,
                    ref_fasta_index = ref_fasta_index,
                    sample_name = sample_id,
                    is_long_reads = is_long_reads,
                    output_gvcf = output_gvcf,
                    intervals = intervals,
                    num_shards = deepvariant_shards,
                    docker = deepvariant_docker_gpu,
                    preemptible = preemptible
            }
        }
        File dv_vcf = select_first([DeepVariant_gpu.vcf, DeepVariant_cpu.vcf])
        File dv_vcf_index = select_first([DeepVariant_gpu.vcf_index, DeepVariant_cpu.vcf_index])
        Array[File] dv_gvcf_files = select_first([DeepVariant_gpu.gvcf_files, DeepVariant_cpu.gvcf_files])

        if(!vcf_input && defined(extra_fasta) && select_first([SplitReads.extra_bam_number_of_reads, 0]) > 0) {
            call MergeVCFs as MergePrimaryAndExtraVCFs { # combine extra vcf with primary vcf for joint annotating
                input:
                    input_vcfs = select_all([dv_vcf, extra_dv_vcf]),
                    input_vcfs_indexes = [],
                    output_vcf_name = sample_id + ".deepvariant.and.extra.init.vcf.gz",
                    docker = docker,
                    preemptible = preemptible
            }
        }
     }

     File variant_vcf = select_first([MergePrimaryAndExtraVCFs.output_vcf, dv_vcf, vcf])
     File variant_vcf_index = select_first([MergePrimaryAndExtraVCFs.output_vcf_index, dv_vcf_index, vcf_index])
     File realigned_bam = select_first([bam_for_variant_calls, bam])
     File realigned_bai = select_first([bai_for_variant_calls, bai])
     File pass_read_eval_bam = select_first([SplitReads.ref_bam, SplitNCigarLongReads.bam, MarkDuplicates.bam, NormalizeBam.output_bam, StarAlign.bam, mm2.bam, bam])
     File pass_read_eval_bai = select_first([SplitReads.ref_bai, SplitNCigarLongReads.bai, MarkDuplicates.bai, NormalizeBam.output_bai, StarAlign.bai, mm2.bai, bai])

     if(!vcf_input || defined(bam)) {
        call StageVariantReadyBam {
            input:
                input_bam = realigned_bam,
                input_bai = realigned_bai,
                sample_id = sample_id,
                docker = docker,
                preemptible = preemptible
        }
     }

     if((annotate_variants || singlecell_mode) && !filter_ready_vcf) {
        call VariantAnnotation.annotate_variants_wf as AnnotateVariants {
                input:
                    input_vcf = variant_vcf,
                    input_vcf_index = variant_vcf_index,
                    base_name = sample_id + ".deepvariant",
                    cravat_lib_tar_gz = cravat_lib_tar_gz,
                    cravat_lib_dir = cravat_lib_dir,
                    ref_fasta = ref_fasta,
                    ref_fasta_index = ref_fasta_index,
                    cosmic_vcf=cosmic_vcf,
                    cosmic_vcf_index=cosmic_vcf_index,
                    dbsnp_vcf=db_snp_vcf,
                    dbsnp_vcf_index=db_snp_vcf_index,
                    gnomad_vcf=gnomad_vcf,
                    gnomad_vcf_index=gnomad_vcf_index,
                    rna_editing_vcf=rna_editing_vcf,
                    rna_editing_vcf_index=rna_editing_vcf_index,
                    repeat_mask_bed=repeat_mask_bed,
                    ref_splice_adj_regions_bed=ref_splice_adj_regions_bed,
                    scripts_path=scripts_path,
                    plugins_path=plugins_path,
                    genome_version=genome_version,
                    docker = docker,
                    preemptible = preemptible,
	                cpu = variant_annotation_cpu,
                    incl_snpEff = annotate_variants && incl_snpEff,
                    incl_dbsnp = annotate_variants && incl_dbsnp,
                    incl_gnomad = annotate_variants && incl_gnomad,
                    incl_rna_editing = annotate_variants && incl_rna_editing,
                    incl_repeats = annotate_variants && incl_repeats,
                    incl_homopolymers = annotate_variants && incl_homopolymers,
                    incl_splice_dist = annotate_variants && incl_splice_dist,
                    incl_cosmic = annotate_variants && incl_cosmic,
                    incl_cravat = annotate_variants && incl_cravat
            }

      }

      if (filter_variants) {

            call FilterDeepVariantVCF {
                input:
                    input_vcf = select_first([AnnotateVariants.vcf, variant_vcf]),
                    input_vcf_index = select_first([AnnotateVariants.vcf_index, variant_vcf_index]),
                    base_name = sample_id + ".deepvariant",
                    min_gq = deepvariant_min_gq,
                    min_qual = deepvariant_min_qual,
                    min_dp = deepvariant_min_dp,
                    cpu = variant_filtration_cpu,
                    memory = filter_memory,
                    docker = docker,
                    preemptible = preemptible
            }

            if(filter_cancer_variants) {
                call FilterCancerVariants {
                    input:
                        input_vcf = FilterDeepVariantVCF.filtered_vcf,
                        base_name = sample_id + ".deepvariant",
                        scripts_path=scripts_path,
                        docker = docker,
                        preemptible = preemptible
                }

                if(defined(ref_bed)) {
                    call CancerVariantReport {
                        input:
                            input_vcf = FilterCancerVariants.cancer_vcf,
                            base_name = sample_id,
                            ref_fasta = ref_fasta,
                            ref_fasta_index = ref_fasta_index,
                            ref_bed = select_first([ref_bed]),
                            bam=select_first([MarkDuplicates.bam, NormalizeBam.output_bam, StarAlign.bam, mm2.bam, bam]),
                            bai=select_first([MarkDuplicates.bai, NormalizeBam.output_bai, StarAlign.bai, mm2.bai, bai]),
                            docker = docker,
                            preemptible = preemptible
                    }
                }
            }
      }

      if(singlecell_mode && !filter_ready_vcf) {
            call single_cell_report {
                input:
                    input_vcf = select_first([FilterDeepVariantVCF.filtered_vcf, AnnotateVariants.vcf, variant_vcf]),
                    bam = pass_read_eval_bam,
                    bam_index = pass_read_eval_bai,
                    cell_barcode_bam_tag = cell_barcode_bam_tag,
                    umi_bam_tag = umi_bam_tag,
                    base_name = sample_id,
                    scripts_path = scripts_path,
                    docker = docker,
                    preemptible = preemptible,
                    cpu = variant_annotation_cpu
            }
      }
    

    output {
        File deepvariant_vcf = variant_vcf
        File deepvariant_vcf_index = variant_vcf_index
        Array[File]? deepvariant_gvcf = dv_gvcf_files
        File variant_ready_bam_file = select_first([StageVariantReadyBam.variant_ready_bam, realigned_bam])
        File variant_ready_bai_file = select_first([StageVariantReadyBam.variant_ready_bai, realigned_bai])
        File variant_calling_bam = realigned_bam
        File variant_calling_bai = realigned_bai
        File? annotated_vcf = AnnotateVariants.vcf
        File? filtered_vcf = FilterDeepVariantVCF.filtered_vcf
        File? aligned_bam = StarAlign.bam
        File? aligned_bai = StarAlign.bai
        File? output_log_final =  StarAlign.output_log_final
        File? output_SJ =  StarAlign.output_SJ
        File? cancer_igv_report = CancerVariantReport.cancer_igv_report
        File? cancer_variants_tsv = FilterCancerVariants.cancer_variants_tsv
        File? cancer_vcf = FilterCancerVariants.cancer_vcf
        File? single_cell_report_tsv_gz = single_cell_report.report_tsv_gz
    }
}

task single_cell_report {
    input {
        File input_vcf
        File bam
        File bam_index
        String cell_barcode_bam_tag = "CB"
        String umi_bam_tag = "XM"
        String base_name
        String scripts_path

        String docker
        Int preemptible
        Int cpu
        Int disk = ceil((size(bam, "GB") * 4) + (size(bam_index, "GB") * 2) + (size(input_vcf, "GB") * 10) + 20)
    }

    command <<<
        set -ex

        echo "######## Single Cell Variant Report #########"

        ln -sf ~{bam} input.bam
        ln -sf ~{bam_index} input.bam.bai

        ~{scripts_path}/vcf_to_single_cell_variant_report.py \
            --vcf ~{input_vcf}  \
            --bam input.bam \
            --cell_barcode_bam_tag ~{cell_barcode_bam_tag} \
            --umi_bam_tag ~{umi_bam_tag} \
            --output ~{base_name}.single_cell_variant_report.tsv \
            --threads ~{cpu}

        gzip ~{base_name}.single_cell_variant_report.tsv
    >>>

    output {
        File report_tsv_gz = "~{base_name}.single_cell_variant_report.tsv.gz"
    }

    runtime {
        disks: "local-disk " + disk + " HDD"
        docker: docker
        memory: "16G"
        preemptible: preemptible
        cpu : cpu
    }
}

task StageVariantReadyBam {
    input {
        File input_bam
        File input_bai
        String sample_id
        String docker
        Int preemptible
    }

    command <<<
        set -e

        cp ~{input_bam} "~{sample_id}.variant-ready.bam"
        cp ~{input_bai} "~{sample_id}.variant-ready.bam.bai"
    >>>

    output {
        File variant_ready_bam = "~{sample_id}.variant-ready.bam"
        File variant_ready_bai = "~{sample_id}.variant-ready.bam.bai"
    }

    runtime {
        disks: "local-disk " + ceil(size(input_bam, "GB") * 3 + size(input_bai, "GB") * 2 + 10) + " HDD"
        docker: docker
        memory: "1G"
        preemptible: preemptible
        cpu: 1
    }
}

task FilterCancerVariants {
    input {
        String scripts_path
        File input_vcf

        String base_name
        String docker
        Int preemptible
    }


    command <<<
        set -e
        # monitor_script.sh &

        # Groom before table conversion
        ~{scripts_path}/groom_vcf.py \
        ~{input_vcf} ~{base_name}.cancer.groom.vcf

        ~{scripts_path}/filter_vcf_for_cancer_prediction_report.py \
        ~{base_name}.cancer.groom.vcf \
        ~{base_name}.cancer.groom.filt.vcf

        # Groom before table conversion
        ~{scripts_path}/groom_vcf.py \
        ~{base_name}.cancer.groom.filt.vcf \
        ~{base_name}.cancer.vcf

        # Convert filtered VCF file to tab file using bcftools (no GATK dependency)
        # Generate header
        echo -e "CHROM\tPOS\tREF\tALT\tGENE\tDP\tQUAL\tMQ\tclinvar_sig\tTUMOR\tTISSUE\tCOSMIC_ID\tFATHMM\tchasmplus_pval\tvest_pval\tmupit_link" > ~{base_name}.cancer.tsv

        # Extract fields with bcftools
        bcftools query -f '%CHROM\t%POS\t%REF\t%ALT\t%INFO/GENE\t%INFO/DP\t%QUAL\t%INFO/MQ\t%INFO/clinvar_sig\t%INFO/TUMOR\t%INFO/TISSUE\t%INFO/COSMIC_ID\t%INFO/FATHMM\t%INFO/chasmplus_pval\t%INFO/vest_pval\t%INFO/mupit_link\n' \
            ~{base_name}.cancer.vcf >> ~{base_name}.cancer.tsv || true

    >>>

    runtime {
        disks: "local-disk " + ceil((size(input_vcf, "GB") * 12) + 30) + " HDD"
        docker: docker
        memory: "8G"
        preemptible: preemptible
        cpu : 1
    }
    output {
        File cancer_variants_tsv = "~{base_name}.cancer.tsv"
        File cancer_vcf = "~{base_name}.cancer.vcf"
    }
}

task CancerVariantReport {
    input {

        File input_vcf
        File bam
        File bai

        File ref_fasta
        File ref_fasta_index
        File ref_bed
        String base_name
        String docker
        Int preemptible
    }

    command <<<
        set -e
        # monitor_script.sh &

        create_report \
        ~{input_vcf} \
        ~{ref_fasta} \
        --flanking 1000 \
        --info-columns-prefixes COSMIC_ID \
        --info-columns GENE clinvar_sig FATHMM TISSUE TUMOR chasmplus_pval vest_pval mupit_link \
        --tracks ~{bam} \
        ~{ref_bed} \
        --output ~{base_name}.cancer.igvjs_viewer.html
    >>>

    runtime {
        disks: "local-disk " + ceil((size(bam, "GB") * 3) + 30) + " HDD"
        docker: docker
        memory: "2G"
        preemptible: preemptible
        cpu : 1
    }
    output {
        File cancer_igv_report = "~{base_name}.cancer.igvjs_viewer.html"
    }
}


task MarkDuplicates {
    input {
        File input_bam
        String base_name
        String docker
        Float memory
        Int preemptible
    }
    Int command_mem = ceil(memory*1000 - 500)

    command <<<
        set -e
        # monitor_script.sh &


        java -Xmx~{command_mem}m -jar /usr/local/src/picard.jar \
        MarkDuplicates \
        INPUT=~{input_bam} \
        OUTPUT=~{base_name}.bam  \
        CREATE_INDEX=true \
        METRICS_FILE=~{base_name}.metrics
    >>>

    output {
        File bam = "${base_name}.bam"
        File bai = "${base_name}.bai"
        File metrics_file = "${base_name}.metrics"
    }

    runtime {
        disks: "local-disk " + ceil(((size(input_bam, "GB") + 2) * 10)) + " HDD"
        docker: docker
        memory: memory + "GB"
        preemptible: preemptible
    }

}

task AddOrReplaceReadGroups {
    input {
        File input_bam
        String sequencing_platform
        String base_name
        String docker
        Int preemptible
        String sample_id
    }
    String unique_id = sub(sample_id, "\\.", "_")

    command <<<
        set -e

        picard AddOrReplaceReadGroups \
        INPUT=~{input_bam} \
        OUTPUT=~{base_name}.sorted.bam \
        SORT_ORDER=coordinate \
        RGID=id \
        RGLB=library \
        RGPL=~{sequencing_platform} \
        RGPU=machine \
        RGSM=~{unique_id}

        samtools index "~{base_name}.sorted.bam"
    >>>

    output {
        File bam = "~{base_name}.sorted.bam"
        File bai = "~{base_name}.sorted.bam.bai"
    }

    runtime {
        memory: "1G"
        disks: "local-disk " + ceil((size(input_bam, "GB") * 3) + 30) + " HDD"
        docker: docker
        preemptible: preemptible
    }
}

task StarAlign {
    input {
        File? star_reference
        String? star_reference_dir
        File? fastq1
        File? fastq2
        Int cpu
        Float memory
        String base_name
        String docker
        Int preemptible
        Float extra_disk_space
        Float fastq_disk_space_multiplier
        Boolean use_ssd
        File? genomeFastaFiles
        Boolean output_unmapped_reads
        String STAR_limitBAMsortRAM
    }
    command <<<
        set -ex

        genomeDir="~{star_reference}"
        if [ "$genomeDir" == "" ]; then
            genomeDir="~{star_reference_dir}"
        fi

        if [ -f "${genomeDir}" ] ; then
            mkdir genome_dir
            #compress="pigz"

            #if [[ $genomeDir == *.bz2 ]] ; then
            #    compress="pbzip2"
            #fi
            #tar -I $compress -xf $genomeDir -C genome_dir --strip-components 1
            tar  -xf $genomeDir -C genome_dir --strip-components 1
            genomeDir="genome_dir"
        fi

        fastq1="~{fastq1}"
        fastq2="~{fastq2}"
        read_files=("$fastq1")
        if [ -n "$fastq2" ]; then
            read_files+=("$fastq2")
        fi
        readFilesCommand=()
        if [[ "~{fastq1}" == *.gz ]] ; then
            readFilesCommand=(--readFilesCommand "gunzip -c")
        fi

        # special case for tar of fastq files
        if [[ "~{fastq1}" == *.tar.gz ]] ; then
            mkdir fastq
            tar -I pigz -xvf ~{fastq1} -C fastq
            mapfile -t read_files < <(find fastq -type f | sort)
            readFilesCommand=()
            if [ "${#read_files[@]}" -gt 0 ] && [[ "${read_files[0]}" == *.gz ]] ; then
                readFilesCommand=(--readFilesCommand "gunzip -c")
            fi
        fi

        STAR \
        --genomeDir "$genomeDir" \
        --runThreadN ~{cpu} \
        --readFilesIn "${read_files[@]}" \
        "${readFilesCommand[@]}" \
        --outSAMtype BAM SortedByCoordinate \
        --twopassMode Basic \
        --limitBAMsortRAM ~{STAR_limitBAMsortRAM} \
        --outSAMmapqUnique 60 \
        --outFileNamePrefix ~{base_name}. \
        ~{'--genomeFastaFiles ' + genomeFastaFiles} ~{true='--outReadsUnmapped Fastx' false='' output_unmapped_reads} \


        if [ "~{output_unmapped_reads}" == "true" ] ; then
            mv ~{base_name}.Unmapped.out.mate1 ~{base_name}.Unmapped.out.mate1.fastq
            mv ~{base_name}.Unmapped.out.mate2 ~{base_name}.Unmapped.out.mate2.fastq
        fi

        samtools index "~{base_name}.Aligned.sortedByCoord.out.bam"

    >>>

    output {
        File bam = "~{base_name}.Aligned.sortedByCoord.out.bam"
        File bai = "~{base_name}.Aligned.sortedByCoord.out.bam.bai"
        File output_log_final = "~{base_name}.Log.final.out"
        File output_log = "~{base_name}.Log.out"
        File output_SJ = "~{base_name}.SJ.out.tab"
        Array[File] unmapped_reads = glob("~{base_name}.Unmapped.out.*")
    }

    runtime {
        preemptible: preemptible
        disks: "local-disk " + ceil(size(fastq1, "GB")*fastq_disk_space_multiplier + size(fastq2, "GB") * fastq_disk_space_multiplier + size(star_reference, "GB")*8 + extra_disk_space) + " " + (if use_ssd then "SSD" else "HDD")
        docker: docker
        cpu: cpu
        memory: memory + "GB"
    }

}


task Minimap2_align {
    input {
        String sample_id
        File? mm2_genome_idx
        File? mm2_splice_bed
        File? reads

        Int cpu
        Float memory
        String docker
        Int preemptible
        Float extra_disk_space
        Float fastq_disk_space_multiplier
        Boolean use_ssd
    }


    command <<<
        set -ex

        minimap2 ~{if defined(mm2_splice_bed) then "--junc-bed " + mm2_splice_bed else ""} -ax splice:hq -u b -t ~{cpu} ~{mm2_genome_idx} ~{reads} > mm2.sam

        samtools view -Sb -o mm2.unsorted.bam mm2.sam
        
        rm mm2.sam # free up disk
        
        samtools sort -@~{cpu} -o ~{sample_id}.mm2.bam mm2.unsorted.bam
        
        samtools index ~{sample_id}.mm2.bam


    >>>

    output {
        File bam = "~{sample_id}.mm2.bam"
        File bai = "~{sample_id}.mm2.bam.bai"
    }

    runtime {
        preemptible: preemptible
        disks: "local-disk " + ceil(size(reads, "GB")*fastq_disk_space_multiplier + size(mm2_genome_idx, "GB")*8 + extra_disk_space) + " " + (if use_ssd then "SSD" else "HDD")
        docker: docker
        cpu: cpu
        memory: memory + "GB"
    }

}


task DeepVariant_cpu {
    input {
        File input_bam
        File input_bam_index
        File ref_fasta
        File ref_fasta_index
        String sample_name
        Boolean is_long_reads
        Boolean output_gvcf = false
        File? intervals
        Int num_shards = 18
        String docker
        Int preemptible
        Int cpu = 18
        Float memory = 36
    }

    String model_type = if is_long_reads then "MASSEQ" else "RNASEQ"

    command <<<
        set -ex

        /opt/deepvariant/bin/run_deepvariant \
            --model_type=~{model_type} \
            --ref=~{ref_fasta} \
            --reads=~{input_bam} \
            --output_vcf=~{sample_name}.deepvariant.init.vcf.gz \
            --sample_name=~{sample_name} \
            --disable_small_model \
            --num_shards=~{num_shards} \
            ~{if output_gvcf then "--output_gvcf=" + sample_name + ".deepvariant.g.vcf.gz" else ""} \
            ~{"--regions=" + intervals} \
            --intermediate_results_dir=intermediate_results
    >>>

    output {
        File vcf = "~{sample_name}.deepvariant.init.vcf.gz"
        File vcf_index = "~{sample_name}.deepvariant.init.vcf.gz.tbi"
        Array[File] gvcf_files = glob("~{sample_name}.deepvariant.g.vcf.gz")
    }

    runtime {
        docker: docker
        cpu: cpu
        memory: memory + " GB"
        disks: "local-disk " + ceil(size(input_bam, "GB") * 2 + 100) + " HDD"
        preemptible: preemptible
    }
}


task DeepVariant_gpu {
    input {
        File input_bam
        File input_bam_index
        File ref_fasta
        File ref_fasta_index
        String sample_name
        Boolean is_long_reads
        Boolean output_gvcf = false
        File? intervals
        Int num_shards = 18
        String docker
        Int preemptible
        Int cpu = 18
        Float memory = 36
    }

    String model_type = if is_long_reads then "MASSEQ" else "RNASEQ"

    command <<<
        set -ex

        /opt/deepvariant/bin/run_deepvariant \
            --model_type=~{model_type} \
            --ref=~{ref_fasta} \
            --reads=~{input_bam} \
            --output_vcf=~{sample_name}.deepvariant.init.vcf.gz \
            --sample_name=~{sample_name} \
            --disable_small_model \
            --num_shards=~{num_shards} \
            ~{if output_gvcf then "--output_gvcf=" + sample_name + ".deepvariant.g.vcf.gz" else ""} \
            ~{"--regions=" + intervals} \
            --intermediate_results_dir=intermediate_results
    >>>

    output {
        File vcf = "~{sample_name}.deepvariant.init.vcf.gz"
        File vcf_index = "~{sample_name}.deepvariant.init.vcf.gz.tbi"
        Array[File] gvcf_files = glob("~{sample_name}.deepvariant.g.vcf.gz")
    }

    runtime {
        docker: docker
        cpu: cpu
        memory: memory + " GB"
        disks: "local-disk " + ceil(size(input_bam, "GB") * 2 + 100) + " HDD"
        preemptible: preemptible
        gpuType: "nvidia-tesla-t4"
        gpuCount: 1
    }
}


task flagCorrection {
    input {
        File input_bam
        File input_bam_index
        String base_name
        String docker
        Int preemptible
        Int cpu = 4
        Float memory = 16
    }

    command <<<
        set -ex

        # flagCorrection improves DeepVariant accuracy on long-read RNA-seq
        # Corrects alignment flags for better variant calling
        flagCorrection.sh ~{input_bam} ~{base_name}.corrected.bam

        samtools index ~{base_name}.corrected.bam
    >>>

    output {
        File bam = "~{base_name}.corrected.bam"
        File bai = "~{base_name}.corrected.bam.bai"
    }

    runtime {
        docker: docker
        cpu: cpu
        memory: memory + " GB"
        disks: "local-disk " + ceil(size(input_bam, "GB") * 3 + 50) + " HDD"
        preemptible: preemptible
    }
}


task FilterDeepVariantVCF {
    input {
        File input_vcf
        File input_vcf_index
        String base_name
        Int min_gq = 18  # DeepVariant recommended threshold for high precision
        Int min_qual = 20
        Int min_dp = 5
        Int cpu = 1
        Float memory = 4
        String docker
        Int preemptible
    }

    command <<<
        set -ex

        # Apply DeepVariant quality filtering (GQ >= 18 recommended for RNA-seq)
        # Per research: achieves 0.998 SNP precision, 0.989 INDEL precision
        bcftools filter \
            -i 'QUAL>=~{min_qual} && FORMAT/GQ>=~{min_gq} && FORMAT/DP>=~{min_dp}' \
            -s LowQuality \
            -O z \
            -o ~{base_name}.filtered.vcf.gz \
            ~{input_vcf}

        tabix -p vcf ~{base_name}.filtered.vcf.gz
    >>>

    output {
        File filtered_vcf = "~{base_name}.filtered.vcf.gz"
        File filtered_vcf_index = "~{base_name}.filtered.vcf.gz.tbi"
    }

    runtime {
        docker: docker
        memory: memory + " GB"
        cpu: cpu
        disks: "local-disk " + ceil(size(input_vcf, "GB") * 2 + 20) + " HDD"
        preemptible: preemptible
    }
}


task MergeVCFs {
    input {
        Array[File] input_vcfs
        Array[File] input_vcfs_indexes
        String output_vcf_name
        Int disk_size = 5
        String docker
        Int preemptible
    }

    output {
        File output_vcf = output_vcf_name
        File output_vcf_index = "${output_vcf_name}.tbi"
    }
    command <<<
        set -e
        # monitor_script.sh &

        python <<CODE
        # make sure vcf index exists
        import subprocess
        import os
        input_vcfs = '~{sep=',' input_vcfs}'.split(',')
        for input_vcf in input_vcfs:
            if not os.path.exists(input_vcf + '.tbi') and not os.path.exists(input_vcf + '.csi') and not os.path.exists(input_vcf + '.idx'):
                subprocess.check_call(['bcftools', 'index', '-t', input_vcf])
        CODE

        # Use bcftools concat instead of GATK MergeVcfs (no GATK dependency)
        bcftools concat \
            --allow-overlaps \
            -O z \
            -o ~{output_vcf_name} \
            ~{sep=" " input_vcfs}

        tabix -p vcf ~{output_vcf_name}

    >>>
    runtime {
        memory: "2.5 GB"
        disks: "local-disk " + disk_size + " HDD"
        docker: docker
        preemptible: preemptible
    }

}

task MergeRealignedBams {
    input {
        Array[File] input_bams
        String output_bam_name
        String output_bai_name
        Int disk_size = 100
        String docker
        Int preemptible
    }

    output {
        File output_realigned_bam = output_bam_name
        File output_realigned_bai = output_bai_name
    }
    command <<<
        set -ex
        # monitor_script.sh &

        samtools merge ~{output_bam_name} ~{sep=" " input_bams}
        samtools index ~{output_bam_name} ~{output_bai_name}

    >>>
    runtime {
        memory: "2.5 GB"
        disks: "local-disk " + disk_size + " HDD"
        docker: docker
        preemptible: preemptible
    }

}

task MergeFastas {
    input {
        File ref_fasta
        File? extra_fasta
        String docker
        Int preemptible
        String name
    }


    command <<<
        cat ~{ref_fasta} ~{extra_fasta} > ~{name}.fa
        samtools faidx ~{name}.fa
    >>>

    runtime {
        docker: docker
        bootDiskSizeGb: 12
        memory: "2G"
        disks: "local-disk " + ceil(10 + 2*size(ref_fasta, "GB"))  + " HDD"
        preemptible: preemptible
        cpu: 1
    }

    output {
        File fasta = "~{name}.fa"
        File fasta_index = "~{name}.fa.fai"
    }
}

task CreateFastaIndex {
    input {
        File? input_fasta
        String docker
        Int preemptible
    }
    String fasta_basename = basename(select_first([input_fasta]))
    command <<<

        cp ~{input_fasta} ~{fasta_basename}
        samtools faidx ~{fasta_basename}
    >>>

    runtime {
        docker: docker
        bootDiskSizeGb: 12
        memory: "2G"
        disks: "local-disk " + ceil(size(input_fasta, "GB")*2) + " HDD"
        preemptible: preemptible
        cpu: 1
    }

    output {
        File fasta = fasta_basename
        File fasta_index = "~{fasta_basename}.fai"
    }
}

task SplitReads {
    input {
        File? input_bam
        File? input_bam_index
        File ref_fasta_index
        File? extra_fasta_index
        String docker
        Int preemptible
        String extra_name
        String ref_name
    }

    command <<<

        python <<CODE
        extra_chr = []
        ref_chr = []

        def parse_fai(path):
            values = set()
            with open(path, 'rt') as f:
                for line in f:
                    line = line.strip()
                    if line != '':
                        values.add(line.split('\t')[0])
            return values

        def to_txt(values, path):
            is_first = True
            with open(path, 'wt') as f:
                for val in values:
                    if not is_first:
                        f.write(' ')
                    f.write(val)
                    is_first = False

        extra_chr = parse_fai('~{extra_fasta_index}')
        ref_chr = parse_fai('~{ref_fasta_index}')
        ref_chr = ref_chr - extra_chr

        to_txt(ref_chr, 'ref.txt')
        to_txt(extra_chr, 'extra.txt')
        CODE

        read -r -a extra_regions < extra.txt
        read -r -a ref_regions < ref.txt

        samtools view -b ~{input_bam} "${extra_regions[@]}" > ~{extra_name}.bam
        samtools view -b ~{input_bam} "${ref_regions[@]}" > ~{ref_name}.bam

        samtools index ~{extra_name}.bam
        samtools index ~{ref_name}.bam

        samtools view -c -F 260 ~{extra_name}.bam > "~{extra_name}_nreads.txt"

    >>>

    runtime {
        docker: docker
        bootDiskSizeGb: 12
        memory: "2G"
        disks: "local-disk " + ceil(size(input_bam, "GB")*2 + size(extra_fasta_index, "GB")*2) + " HDD"
        preemptible: preemptible
        cpu: 1
    }

    output {
        File extra_bam = "~{extra_name}.bam"
        File extra_bai = "~{extra_name}.bam.bai"
        File ref_bam = "~{ref_name}.bam"
        File ref_bai = "~{ref_name}.bam.bai"
        Int extra_bam_number_of_reads = read_int("~{extra_name}_nreads.txt")
    }
}


task CreateBamIndex {
    input {
        File input_bam
        String docker
        Int preemptible
        String memory
    }
    String name = basename(input_bam)

    output {
        File bai = "~{name}.bai"
    }
    command <<<
        set -e

        # monitor_script.sh &

        samtools index ~{input_bam}

        mv ~{input_bam}.bai .
    >>>

    runtime {
        disks: "local-disk " + ceil(1+size(input_bam, "GB")*1.5) + " HDD"
        docker: docker
        memory: memory
        preemptible: preemptible
    }
}


task SplitNCigarLongReads {
    input {
        File input_bam
        File input_bam_index
        String cell_barcode_bam_tag = "CB"
        String umi_bam_tag = "XM"
        String scripts_path
        Float memory = 8
        
        String docker
        Int preemptible
        
    }

    String output_bam_filename = basename(input_bam, ".bam") + ".splitNcigar.bam"
    
    command <<<
        set -euo pipefail
        # monitor_script.sh &

        cmd="~{scripts_path}/cigar_N_splitter.py --cell_barcode_bam_tag ~{cell_barcode_bam_tag} --umi_bam_tag ~{umi_bam_tag} ~{input_bam} split_N.bam; samtools sort split_N.bam -o ~{output_bam_filename}"
        comment="Split reads on N CIGAR operations and sorted into ~{output_bam_filename}"
        pg_id="SplitNCigarLongReads_~{basename(output_bam_filename, ".bam")}"

        ~{scripts_path}/cigar_N_splitter.py \
            --cell_barcode_bam_tag ~{cell_barcode_bam_tag} \
            --umi_bam_tag ~{umi_bam_tag} \
            ~{input_bam} split_N.bam

        samtools sort split_N.bam -o ~{output_bam_filename}

        samtools view -H ~{output_bam_filename} > header.sam

        last_pg_id=$(awk -F'\t' '$1=="@PG" { for (i=2; i<=NF; i++) if ($i ~ /^ID:/) id=substr($i,4) } END { print id }' header.sam)

        {
            cat header.sam
            if [ -n "${last_pg_id:-}" ]; then
                printf '@PG\tID:%s\tPN:cigar_N_splitter.py\tPP:%s\tCL:%s\n' "$pg_id" "$last_pg_id" "$cmd"
            else
                printf '@PG\tID:%s\tPN:cigar_N_splitter.py\tCL:%s\n' "$pg_id" "$cmd"
            fi
            printf '@CO\t%s\n' "$comment"
        } > header.with_provenance.sam

        samtools reheader header.with_provenance.sam ~{output_bam_filename} > tmp.reheadered.bam
        mv tmp.reheadered.bam ~{output_bam_filename}

        samtools index ~{output_bam_filename}
        
    >>>


    output {
        File bam = "~{output_bam_filename}"
        File bai = "~{output_bam_filename}.bai"
    }
        
    runtime {
        disks: "local-disk " + ceil((size(input_bam, "GB") + 10) * 10 ) + " SSD"
        docker: docker
        memory: memory + "GB"
        preemptible: preemptible
    }
}





task NormalizeBam {
    input {
        File input_bam
        Int max_coverage = 1000
        Boolean use_bamsifter = false
        String scripts_path
        String docker
        Int preemptible
    }
    
    String output_bam_filename = basename(input_bam) + ".norm~{max_coverage}.bam"
    
    command <<<

        set -euo pipefail

        cmd="~{scripts_path}/normalize_bam_by_strand.py --input_bam ~{input_bam} --normalize_max_cov_level ~{max_coverage} ~{if use_bamsifter then "--use_bamsifter" else ""} --output_bam ~{output_bam_filename}"
        comment="Normalized BAM by strand with max coverage ~{max_coverage} into ~{output_bam_filename}"
        pg_id="NormalizeBam_~{basename(output_bam_filename, ".bam")}"

        ~{scripts_path}/normalize_bam_by_strand.py --input_bam ~{input_bam} \
            --normalize_max_cov_level ~{max_coverage} \
            ~{if use_bamsifter then "--use_bamsifter" else ""} \
            --output_bam ~{output_bam_filename}

        samtools view -H ~{output_bam_filename} > header.sam

        last_pg_id=$(awk -F'\t' '$1=="@PG" { for (i=2; i<=NF; i++) if ($i ~ /^ID:/) id=substr($i,4) } END { print id }' header.sam)

        {
            cat header.sam
            if [ -n "${last_pg_id:-}" ]; then
                printf '@PG\tID:%s\tPN:normalize_bam_by_strand.py\tPP:%s\tCL:%s\n' "$pg_id" "$last_pg_id" "$cmd"
            else
                printf '@PG\tID:%s\tPN:normalize_bam_by_strand.py\tCL:%s\n' "$pg_id" "$cmd"
            fi
            printf '@CO\t%s\n' "$comment"
        } > header.with_provenance.sam

        samtools reheader header.with_provenance.sam ~{output_bam_filename} > tmp.reheadered.bam
        mv tmp.reheadered.bam ~{output_bam_filename}

        samtools index ~{output_bam_filename}

    >>>

    output {
        File output_bam = "~{output_bam_filename}"
        File output_bai = "~{output_bam_filename}.bai"
    }

    runtime {
        docker: docker
        bootDiskSizeGb: 12
        memory: "32G"
        disks: "local-disk " + ceil(size(input_bam, "GB")*6 + 10) + " HDD"
        preemptible: preemptible
        cpu: 1
    }

}
