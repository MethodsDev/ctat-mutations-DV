version 1.0

import "../ctat-mutations-DV.wdl" as CTAT_Mutations_wf


struct Ctat_mutations_config {

  File gtf
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
    String sample_id
    File? bam
    File? bai  
    File? left
    File? right
    File? intervals
    Boolean is_long_reads = false
    Boolean annotate_variants = true
    Int? preemptible  
    Ctat_mutations_config pipe_inputs_config
  }
  
  call CTAT_Mutations_wf.ctat_mutations_DV as CM_wf {

    input:
      docker = docker,
      sample_id = sample_id,
      bam = bam,
      bai = bai,
      left = left,
      right = right,

      intervals = intervals,
      annotate_variants = annotate_variants,

      is_long_reads = is_long_reads,

      gtf = pipe_inputs_config.gtf,
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

      preemptible = preemptible
   }


    output {
        # DeepVariant outputs (v5.0.0+)
        File? deepvariant_vcf = CM_wf.deepvariant_vcf
        File? deepvariant_vcf_index = CM_wf.deepvariant_vcf_index
        Array[File]? deepvariant_gvcf = CM_wf.deepvariant_gvcf

        # Variant calling BAM (replaces haplotype_caller_realigned_bam)
        File? variant_calling_bam = CM_wf.variant_calling_bam
        File? variant_calling_bai = CM_wf.variant_calling_bai

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

        # Single-cell variant reads (if applicable)
        File? sc_var_reads = CM_wf.sc_var_reads

    }
}


