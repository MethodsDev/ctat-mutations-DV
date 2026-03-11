version 1.0


import "ctat-mutations-DV.Terra.wdl" as CTAT_Mutations_Terra


workflow ctat_mutations_DV_Terra_hg38 {


  input {

    String docker = "trinityctat/ctat_mutations_dv:latest"
    String deepvariant_docker = "google/deepvariant:1.10.0"
    String deepvariant_docker_gpu = "google/deepvariant:1.10.0-gpu"
    Boolean deepvariant_use_gpu = false
    String sample_id
    File? fastq_left
    File? fastq_right
    File? bam
    File? bai
    File? intervals
    Boolean annotate_variants = true
    Boolean is_long_reads = false
    Int? preemptible

    # annotation toggles
    Boolean incl_snpEff = true
    Boolean incl_dbsnp = true
    Boolean incl_gnomad = true
    Boolean incl_rna_editing = true
    Boolean incl_repeats = true
    Boolean incl_homopolymers = true
    Boolean incl_splice_dist = true
    Boolean incl_cosmic = true
    Boolean incl_blat_ED = false
    Boolean include_read_var_pos_annotations = false
    Boolean incl_cravat = false
  

	String gs_base_url = "gs://mdl-ctat-genome-libs/__genome_libs_StarFv1.10/GRCh38_gencode_v22_CTAT_lib_Mar012021.plug-n-play"


    Ctat_mutations_config pipe_inputs_config = {
      "genome_version" : "hg38",
      "ref_bed" : gs_base_url + "/ctat_mutation_lib/refGene.sort.bed.gz",
      "ref_fasta" : gs_base_url + "/ref_genome.fa",
      "ref_fasta_index" : gs_base_url + "/ref_genome.fa.fai",
      "cravat_lib_tar_gz" : gs_base_url + "/ctat_mutation_lib/cravat.tar.bz2",
      "db_snp_vcf" : gs_base_url + "/ctat_mutation_lib/dbsnp.vcf.gz",
      "db_snp_vcf_index" : gs_base_url + "/ctat_mutation_lib/dbsnp.vcf.gz.tbi",
      "cosmic_vcf" : gs_base_url + "/ctat_mutation_lib/cosmic.vcf.gz",
      "cosmic_vcf_index" : gs_base_url + "/ctat_mutation_lib/cosmic.vcf.gz.csi",
      "gnomad_vcf" : gs_base_url + "/ctat_mutation_lib/gnomad-lite.vcf.gz",
      "gnomad_vcf_index" : gs_base_url + "/ctat_mutation_lib/gnomad-lite.vcf.gz.csi",
      "ref_splice_adj_regions_bed" : gs_base_url + "/ctat_mutation_lib/ref_annot.splice_adj.bed.gz",
      "repeat_mask_bed" : gs_base_url + "/ctat_mutation_lib/repeats_ucsc_gb.bed.gz",
      "rna_editing_vcf" : gs_base_url + "/ctat_mutation_lib/RNAediting.library.vcf.gz",
      "rna_editing_vcf_index" : gs_base_url + "/ctat_mutation_lib/RNAediting.library.vcf.gz.csi",
      "star_reference" : gs_base_url + "/ref_genome.fa.star.idx.tar.bz2",
      "mm2_genome_idx" : gs_base_url + "/ref_genome.fa.mm2",
      "mm2_splice_bed" : gs_base_url + "/ref_annot.gtf.mm2.splice.bed"

    }

  }
  

  call CTAT_Mutations_Terra.ctat_mutations_Terra as CM_Terra_wf {

    input:
      docker = docker,
      deepvariant_docker = deepvariant_docker,
      deepvariant_docker_gpu = deepvariant_docker_gpu,
      deepvariant_use_gpu = deepvariant_use_gpu,
      sample_id = sample_id,
      fastq_left = fastq_left,
      fastq_right = fastq_right,
      bam = bam,
      bai = bai,
      intervals = intervals,
      annotate_variants = annotate_variants,
      is_long_reads = is_long_reads,
      pipe_inputs_config = pipe_inputs_config,
      preemptible = preemptible,

      incl_snpEff = incl_snpEff,
      incl_dbsnp = incl_dbsnp,
      incl_gnomad = incl_gnomad,
      incl_rna_editing = incl_rna_editing,
      incl_repeats = incl_repeats,
      incl_homopolymers = incl_homopolymers,
      incl_splice_dist = incl_splice_dist,
      incl_cosmic = incl_cosmic,
      incl_blat_ED = incl_blat_ED,
      include_read_var_pos_annotations = include_read_var_pos_annotations,
      incl_cravat = incl_cravat

  }

 output {
        # DeepVariant outputs (v5.0.0+)
        File? deepvariant_vcf = CM_Terra_wf.deepvariant_vcf
        File? deepvariant_vcf_index = CM_Terra_wf.deepvariant_vcf_index
        Array[File]? deepvariant_gvcf = CM_Terra_wf.deepvariant_gvcf

        # Variant calling BAM (replaces haplotype_caller_realigned_bam)
        File? variant_calling_bam = CM_Terra_wf.variant_calling_bam
        File? variant_calling_bai = CM_Terra_wf.variant_calling_bai

        # Annotated and filtered VCFs
        File? annotated_vcf = CM_Terra_wf.annotated_vcf
        File? filtered_vcf = CM_Terra_wf.filtered_vcf

        # Alignment outputs
        File? aligned_bam = CM_Terra_wf.aligned_bam
        File? aligned_bai = CM_Terra_wf.aligned_bai
        File? output_log_final = CM_Terra_wf.output_log_final
        File? output_SJ = CM_Terra_wf.output_SJ

        # Cancer variant reports
        File? cancer_igv_report = CM_Terra_wf.cancer_igv_report
        File? cancer_variants_tsv = CM_Terra_wf.cancer_variants_tsv
        File? cancer_vcf = CM_Terra_wf.cancer_vcf

        # Single-cell variant reads (if applicable)
        File? sc_var_reads = CM_Terra_wf.sc_var_reads

 }


}


