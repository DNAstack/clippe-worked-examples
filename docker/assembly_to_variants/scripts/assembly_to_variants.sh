#!/bin/bash

usage() {
cat << EOF
Usage: $0 -s accession -a assembly_fasta -g reference_genome_id -r reference_fasta
EOF
}


while getopts "hs:a:g:r:" OPTION; do
	case $OPTION in
		h) usage; exit;;
		s) sample=$OPTARG;;
		a) fasta=$OPTARG;;
		g) REFERENCE_GENOME_ID=$OPTARG;;
		r) NCBI_REFERENCE_FASTA=$OPTARG;;
		\?) usage; exit;;
	esac
done


if [[ -z "${sample}" || -z "${fasta}" || -z "${REFERENCE_GENOME_ID}" || -z "${NCBI_REFERENCE_FASTA}" ]]; then
	usage
	echo "Must specify sample (${sample:-unspecified}), assembly fasta (${fasta:-unspecified}), reference genome ID (${REFERENCE_GENOME_ID:-unspecified}), reference fasta (${NCBI_REFERENCE_FASTA:-unspecified})"
	exit 1
fi


# splitFasta multifasta_file output_dir
function splitFasta() {
	MULTIFASTA=$1
	OUTPUT_DIR=$2

	awk -v OUTPUT_DIR="${OUTPUT_DIR}" '{if (substr($0, 1, 1)==">") {num_digits=index($0, " ")-2;filename=(substr($0,2,num_digits) ".fa")} print $0 > OUTPUT_DIR"/"filename}' \
		< "${MULTIFASTA}"
}


## VCF header lines
VCF_GENERIC_HEADER="##fileformat=VCFv4.1\n##FILTER=<ID=PASS,Description=\"All filters passed\">\n##contig=<ID=NC_045512,length=29903>\n##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">"
VCF_REFERENCE_LINE="##reference=file:///${REFERENCE_GENOME_ID}.fasta"
VCF_BLASTN_VERSION="##blastnVersion=\"2.6.0+\""
VCF_MVIEW_VERSION="##mviewVersion=\"1.67\""
VCF_SNP_SITES_VERSION="##snp-sitesVersion=\"2.3.2\""
VCF_BLASTN_COMMANDLINE="##blastnCmd=\"blastn -query NC_045512.fasta -subject ${sample}.fasta -outfmt 0 | mview -in blast -out fasta > ${sample}.aln.fasta\""
VCF_SNP_SITES_COMMANDLINE="##snp-sitesCmd=\"snp-sites ${sample}.aln.fasta -v -o ${sample}.vcf\""

NCBI_STRAIN_ACRONYM="SARS-CoV2"

DATE=$(date -u +"%F_%T")

ANNOTATIONS_DIR=/data/annotations
VCF_DIR=.
TMPDIR=./tmp


mkdir -p ${TMPDIR}



# Create a map file that will allow bcftools to rename vcf chr from 1 > ${REFERENCE_GENOME_ID}
echo -e "1\t${REFERENCE_GENOME_ID}" >> "${TMPDIR}"/chr_map_file.txt


# Including the full reference sequence in the BLAST subject file forces the output positions to match up to the base numbering of the full reference
# (Otherwise numbering is based on the first position that the subject matches in the reference, which could be > position 1 of the reference -- position in VCF would be wrong)
cat <(sed "1s~.*~>${sample}~" "${fasta}") "${NCBI_REFERENCE_FASTA}" >> "${TMPDIR}"/"${sample}".tmp.fasta
blastn \
	-query "${NCBI_REFERENCE_FASTA}" \
	-subject "${TMPDIR}"/"${sample}".tmp.fasta \
	-outfmt 0 | \
mview \
	-in blast \
	-out fasta | \
sed 's/[0-9]://g' > \
	"${TMPDIR}/${sample}.tmp.aln.fasta"


# tmp.fasta will have duplicate entries for the reference sequence; one from query, one from subject
# We extract the aligned region for the sample and overwrite tmp.fasta to include a single entry for reference sequence and a single entry for the sample aligned region
# reference sequence must be the first entry in tmp.fasta for snp-sites to work
splitFasta "${TMPDIR}/${sample}.tmp.aln.fasta" "${TMPDIR}"
if [ -e "${TMPDIR}"/"${sample}".fa ]; then
	cat ${NCBI_REFERENCE_FASTA} "${TMPDIR}"/"${sample}".fa > "${TMPDIR}"/"${sample}".tmp.aln.fasta && rm "${TMPDIR}"/*.fa

	set +e
	snp-sites \
		"${TMPDIR}"/"${sample}".tmp.aln.fasta \
		-v \
		-o "${TMPDIR}"/"${sample}".tmp.vcf
	set -e
	if [ -e "${TMPDIR}"/"${sample}".tmp.vcf ]; then
		bcftools view \
			--no-update \
			-s "${sample}" \
			"${TMPDIR}"/"${sample}".tmp.vcf | \
		bcftools annotate \
			--rename-chrs "${TMPDIR}"/chr_map_file.txt \
			- \
			-o "${TMPDIR}"/"${sample}".tmp.renamed.vcf

		# Clean up header; add tool versions
		header=$(bcftools view \
			--no-update \
			-h \
			"${TMPDIR}"/"${sample}".tmp.renamed.vcf | head -n -1)
		chrom_line=$(bcftools view \
			--no-update \
			-h \
			"${TMPDIR}"/"${sample}".tmp.renamed.vcf | tail -1)

		echo -e "${header}\n${VCF_REFERENCE_LINE}\n${VCF_BLASTN_VERSION}\n${VCF_MVIEW_VERSION}\n${VCF_SNP_SITES_VERSION}\n${VCF_BLASTN_COMMANDLINE}\n${VCF_SNP_SITES_COMMANDLINE}\n${chrom_line}" > "${TMPDIR}"/"${sample}".header.txt

		bcftools reheader \
			-h "${TMPDIR}"/"${sample}".header.txt \
			"${TMPDIR}"/"${sample}".tmp.renamed.vcf \
			-o "${VCF_DIR}"/"${sample}".vcf

		rm "${TMPDIR}"/"${sample}".tmp.vcf "${TMPDIR}"/"${sample}".tmp.renamed.vcf "${TMPDIR}"/"${sample}".header.txt
	else
		CHROM_LINE="#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t${sample}"
		# No variants found
		echo -e "${VCF_GENERIC_HEADER}\n${VCF_REFERENCE_LINE}\n${VCF_BLASTN_VERSION}\n${VCF_MVIEW_VERSION}\n${VCF_SNP_SITES_VERSION}\n${VCF_BLASTN_COMMANDLINE}\n${VCF_SNP_SITES_COMMANDLINE}\n${CHROM_LINE}" \
			> "${VCF_DIR}"/"${sample}".vcf
	fi
else
	CHROM_LINE="#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t${sample}"
	# No alignments found
	echo -e "${VCF_GENERIC_HEADER}\n${VCF_REFERENCE_LINE}\n${VCF_BLASTN_VERSION}\n${VCF_MVIEW_VERSION}\n${VCF_SNP_SITES_VERSION}\n${VCF_BLASTN_COMMANDLINE}\n${VCF_SNP_SITES_COMMANDLINE}\n${CHROM_LINE}" \
		> "${VCF_DIR}"/"${sample}".vcf
fi

rm "${TMPDIR}"/"${sample}".tmp.fasta "${TMPDIR}"/"${sample}".tmp.aln.fasta


## Annotate
echo -e "${REFERENCE_GENOME_ID}\t1\t29903\t${DATE}" >> "${TMPDIR}"/date.bed
bgzip "${TMPDIR}"/date.bed && tabix -p bed "${TMPDIR}"/date.bed.gz

vcf-annotate \
	-a "${TMPDIR}"/date.bed.gz \
	-c "CHROM,FROM,TO,INFO/PD" \
	-d "key=INFO,ID=PD,Number=1,Type=String,Description='Processing date (YYYY-MM-DD HH:MM:SS) (UTC)'" \
	"${sample}.vcf"

bgzip "${sample}.vcf"
tabix "${sample}.vcf.gz"