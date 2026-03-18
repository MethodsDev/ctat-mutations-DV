version 1.0

import "../ctat-mutations-DV.wdl" as CTAT_Mutations_wf


struct Ctat_mutations_config {

  File ref_bed
  File ref_fasta
  File ref_fasta_index

  String genome_version
    
  File cravat_lib_tar_gz

  File db_snp_vcf
  File db_snp_vcf_index
  
  File cosmic_vcf
  File cosmic_vcf_index
  
  File gnomad_vcf
  File gnomad_vcf_index

  File ref_splice_adj_regions_bed

  File repeat_mask_bed

  File rna_editing_vcf
  File rna_editing_vcf_index
  
  File star_reference

  File mm2_genome_idx
  File mm2_splice_bed

}

  

workflow ctat_mutations_Terra {


  input {
    String docker
    String deepvariant_docker
    String deepvariant_docker_gpu = "google/deepvariant:1.10.0-gpu"
    Boolean deepvariant_use_gpu = false
    String sample_id
    File? bam
    File? bai
    File? fastq_left
    File? fastq_right
    File? intervals
    Boolean is_long_reads = false
    Boolean annotate_variants = true
    Boolean singlecell_mode = false
    String cell_barcode_bam_tag = "CB"
    String umi_bam_tag = "XM"
    Int normalize_max_cov_level = 1000
    Int? preemptible
    Ctat_mutations_config pipe_inputs_config

    # annotation toggles
    Boolean incl_snpEff = true
    Boolean incl_dbsnp = true
    Boolean incl_gnomad = true
    Boolean incl_rna_editing = true
    Boolean incl_repeats = true
    Boolean incl_homopolymers = true
    Boolean incl_splice_dist = true
    Boolean incl_cosmic = true
    Boolean incl_cravat = false
  }
  
  call CTAT_Mutations_wf.ctat_mutations_DV as CM_wf {

    input:
      docker = docker,
      deepvariant_docker = deepvariant_docker,
      deepvariant_docker_gpu = deepvariant_docker_gpu,
      deepvariant_use_gpu = deepvariant_use_gpu,
      sample_id = sample_id,
      bam = bam,
      bai = bai,
      fastq_left = fastq_left,
      fastq_right = fastq_right,

      intervals = intervals,
      annotate_variants = annotate_variants,
      singlecell_mode = singlecell_mode,
      cell_barcode_bam_tag = cell_barcode_bam_tag,
      umi_bam_tag = umi_bam_tag,
      normalize_max_cov_level = normalize_max_cov_level,

      is_long_reads = is_long_reads,

      ref_bed = pipe_inputs_config.ref_bed,
      ref_fasta = pipe_inputs_config.ref_fasta,
      ref_fasta_index = pipe_inputs_config.ref_fasta_index,
      genome_version = pipe_inputs_config.genome_version,
      cravat_lib_tar_gz = pipe_inputs_config.cravat_lib_tar_gz,
      db_snp_vcf = pipe_inputs_config.db_snp_vcf,
      db_snp_vcf_index = pipe_inputs_config.db_snp_vcf_index,
      cosmic_vcf = pipe_inputs_config.cosmic_vcf,
      cosmic_vcf_index = pipe_inputs_config.cosmic_vcf_index,
      gnomad_vcf = pipe_inputs_config.gnomad_vcf,
      gnomad_vcf_index = pipe_inputs_config.gnomad_vcf_index,
      ref_splice_adj_regions_bed = pipe_inputs_config.ref_splice_adj_regions_bed,
      repeat_mask_bed = pipe_inputs_config.repeat_mask_bed,
      rna_editing_vcf = pipe_inputs_config.rna_editing_vcf,
      rna_editing_vcf_index = pipe_inputs_config.rna_editing_vcf_index,
      star_reference = pipe_inputs_config.star_reference,
      mm2_genome_idx = pipe_inputs_config.mm2_genome_idx,
      mm2_splice_bed = pipe_inputs_config.mm2_splice_bed,

      preemptible = preemptible,

      incl_snpEff = incl_snpEff,
      incl_dbsnp = incl_dbsnp,
      incl_gnomad = incl_gnomad,
      incl_rna_editing = incl_rna_editing,
      incl_repeats = incl_repeats,
      incl_homopolymers = incl_homopolymers,
      incl_splice_dist = incl_splice_dist,
      incl_cosmic = incl_cosmic,
      incl_cravat = incl_cravat
   }


    output {
        # DeepVariant outputs (v5.0.0+)
        File deepvariant_vcf = CM_wf.deepvariant_vcf
        File deepvariant_vcf_index = CM_wf.deepvariant_vcf_index
        Array[File]? deepvariant_gvcf = CM_wf.deepvariant_gvcf

        # Variant-ready BAM used for calling
        File variant_ready_bam_file = CM_wf.variant_ready_bam_file
        File variant_ready_bai_file = CM_wf.variant_ready_bai_file

        # Variant calling BAM (replaces haplotype_caller_realigned_bam)
        File variant_calling_bam = CM_wf.variant_calling_bam
        File variant_calling_bai = CM_wf.variant_calling_bai

        # Annotated and filtered VCFs
        File? annotated_vcf = CM_wf.annotated_vcf
        File? filtered_vcf = CM_wf.filtered_vcf

        # Alignment outputs
        File? aligned_bam = CM_wf.aligned_bam
        File? aligned_bai = CM_wf.aligned_bai
        File? output_log_final = CM_wf.output_log_final
        File? output_SJ = CM_wf.output_SJ

        # Cancer variant reports
        File? cancer_igv_report = CM_wf.cancer_igv_report
        File? cancer_variants_tsv = CM_wf.cancer_variants_tsv
        File? cancer_vcf = CM_wf.cancer_vcf

        # Single-cell variant report (if applicable)
        File? single_cell_report_tsv_gz = CM_wf.single_cell_report_tsv_gz

    }
}
