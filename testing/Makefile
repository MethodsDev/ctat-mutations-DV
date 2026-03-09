## CTAT-Mutations v5.0.0 Testing Makefile
## Updated for DeepVariant-based variant calling (removed GATK and boosting tests)

all: DV_standard DV_SE_Reads DV_long_reads DV_SE_Reads_singlecell DV_long_reads_singlecell


########################
## DeepVariant tests

DV_standard:
	../ctat_mutations --left reads_1.fastq.gz --right reads_2.fastq.gz --sample_id example.DV_standard -O example.DV_standard --star_limitBAMsortRAM 400000000

DV_standard_single_thread:
	../ctat_mutations --left reads_1.fastq.gz --right reads_2.fastq.gz --sample_id example.DV_standard.onethread --star_cpu 1 -O example.DV_standard.onethread

DV_standard_w_intervals:
	../ctat_mutations --left reads_1.fastq.gz --right reads_2.fastq.gz --sample_id example.DV_standard -O example.DV_standard_w_intervals --intervals __misc_data/intervals.list

## Using single-end reads:
DV_SE_Reads:
	../ctat_mutations --left reads_1.fastq.gz --sample_id example.DV_standard_SE -O example.DV_standard_SE

# pretend single cell data, do read extractions:
DV_SE_Reads_singlecell:
	../ctat_mutations --left reads_1.fastq.gz --sample_id example.DV_standard_SE -O example.DV_standard_SE.singlecell --is_single_cells

## Using long reads:
DV_long_reads:
	../ctat_mutations --left __misc_data/UHR.pbio.fq.gz --sample_id example.long_reads -O example.long_reads --is_long_reads

DV_long_reads_singlecell:
	../ctat_mutations --left __misc_data/UHR.pbio.fq.gz --sample_id example.long_reads -O example.long_reads.singlecell --is_long_reads --is_single_cells

## DeepVariant-specific parameters
DV_with_gvcf:
	../ctat_mutations --left reads_1.fastq.gz --right reads_2.fastq.gz --sample_id example.DV_gvcf -O example.DV_gvcf --output_gvcf

DV_custom_thresholds:
	../ctat_mutations --left reads_1.fastq.gz --right reads_2.fastq.gz --sample_id example.DV_custom -O example.DV_custom --deepvariant_min_gq 30 --deepvariant_min_qual 30 --deepvariant_min_dp 10

## Docker

DV_standard_docker:
	docker run --rm -v `pwd`:/data -v ${CTAT_GENOME_LIB}:/ctat_genome_lib_dir:ro trinityctat/ctat_mutations:5.0.0 /usr/local/src/ctat-mutations/ctat_mutations --left /data/reads_1.fastq.gz --right /data/reads_2.fastq.gz --sample_id example.DV.docker --genome_lib_dir /ctat_genome_lib_dir -O /data/example.DV_standard.Docker

DV_standard_docker_latest:
	docker run --rm -v `pwd`:/data -v ${CTAT_GENOME_LIB}:/ctat_genome_lib_dir:ro trinityctat/ctat_mutations:latest /usr/local/src/ctat-mutations/ctat_mutations --left /data/reads_1.fastq.gz --right /data/reads_2.fastq.gz --sample_id example.DV.docker --genome_lib_dir /ctat_genome_lib_dir -O /data/example.DV_standard.Docker

## Singularity

DV_standard_singularity:
	singularity exec -e -B `pwd`:/data -B ${CTAT_GENOME_LIB}:/ctat_genome_lib_dir:ro ../Docker/ctat_mutations.v5.0.0.simg /usr/local/src/ctat-mutations/ctat_mutations --left /data/reads_1.fastq.gz --right /data/reads_2.fastq.gz --sample_id example.DV.singularity --genome_lib_dir /ctat_genome_lib_dir -O /data/example.DV_standard.Singularity


##########################################
## Start from genome-specific VCF and BAMs
## (be sure to use the corresponding hg19 or GRCh38 ctat genome lib!!! (or it'll crash)

kickstart_vcf_hg19:
	../ctat_mutations --bam __misc_data/Aligned.sortedByCoord.out.hg19.bam --vcf __misc_data/variants.hg19.vcf --sample_id example.vcf_hg19 -O example.vcf_hg19

kickstart_vcf_GRCh38:
	../ctat_mutations --bam __misc_data/Aligned.sortedByCoord.out.GRCh38.bam --vcf __misc_data/variants.GRCh38.vcf.gz --sample_id example.vcf_GRCh38 -O example.vcf_GRCh38

kickstart_bam_GRCh38_variant_ready:
	../ctat_mutations --bam __misc_data/example.vcf_GRCh38.variant_ready.bam --variant_ready_bam --sample_id example.vcf_GRCh38 -O example.bam_GRCh38_variant_ready


####################
## igv_reports test:

igv_reports_hg37:
	create_report __misc_data/for_igv_reports/cancer.vcf ${CTAT_GENOME_LIB}/ref_genome.fa --flanking 1000 --info-columns GENE TISSUE TUMOR COSMIC_ID GENE SOMATIC CHASM_PVALUE CHASM_FDR VEST_PVALUE VEST_FDR --tracks __misc_data/for_igv_reports/refGene.sort.bed __misc_data/for_igv_reports/recalibrated.bam --output example.igv_report.html


###############
## Cravat tests - using open-cravat

cravat_hg38_builtin:
	mkdir -p example.cravat_hg38
	oc new example-input example.cravat_hg38
	../src/annotate_with_cravat.py --input_vcf example.cravat_hg38/example_input --output_vcf example.cravat_hg38/example-input.wCravat.vcf --genome hg38 --cravat_lib_dir ${CTAT_GENOME_LIB}/ctat_mutation_lib/cravat


##############
## Other misc tests

annotate_PASS_reads:
	../src/annotate_PASS_reads.py --vcf __misc_data/annot_pass_reads/HaplotypeCaller.raw_variants.vcf --bam __misc_data/annot_pass_reads/dedupped.bam --output_vcf test_annot_pass_reads.vcf


###########
## Cleanup

clean:
	rm -rf ./example.*


###########################################################
## Notes on removed tests (v4.x → v5.0.0 migration)
##
## REMOVED:
## - All boosting tests (SGBoost, AdaBoost, RF, XGBoost, LR, NGBoost, SVM)
## - BQSR-related tests
## - HaplotypeCaller-specific parameter tests
## - Benchmark tests comparing boosting methods
##
## CHANGED:
## - HC_* tests renamed to DV_* (DeepVariant)
## - Removed --boosting_method parameter from all tests
## - Removed --HC_xtra_args parameter
## - Removed --no_bqsr parameter
##
## NEW:
## - DV_with_gvcf: Test gVCF output
## - DV_custom_thresholds: Test custom quality thresholds
##
## For v4.x compatibility testing, use the v4.3.0 Docker image:
##   docker pull trinityctat/ctat_mutations:4.3.0
###########################################################
