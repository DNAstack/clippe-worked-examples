version 1.0

workflow variants_from_assembly {
  input {
    String collection_name
    String collections_api_url = "https://viral.ai/api/collections"
    String limit = "10"
  }

  call download_fastas {
    input:
      collections_api_url = collection_name,
      collection_name = collection_name,
      limit = limit,
  }

  scatter (fasta in download_fastas.fastas) {
    call call_variants {
      input:
        assembly = fasta
    }
  }

  output {
    Array[File] annotated_vcf = call_variants.annotated_vcf
    Array[File] annotated_vcf_index = call_variants.annotated_vcf_index
    Array[File] snpEff_summary = call_variants.snpEff_summary
  }
}

task download_fastas {

  input {
    String collections_api_url
    String collection_name
    Int limit
  }

  command <<<
    mkdir outputs
    dnastack config set collections.url "~{collections_api_url}"
    collection_slug_name=$(dnastack collections list | jq -r '.[] | select(.name == "~{collection_name}") | .slugName')
    query="SELECT drs_url FROM \"viralai\".\"$collection_slug_name\".\"files\" WHERE name LIKE '%.fasta' OR name LIKE '%.fa' LIMIT ~{limit}"
    dnastack collections query "$collection_slug_name" "$query" | jq -r '.[].drs_url' | dnastack files download -o outputs
  >>>

  output {
    Array[File] downloaded_data = glob("outputs/*/*")
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/dnastack-cli:v0.3.3"
  }
}

task call_variants {
  input {
    File assembly
  }

  String accession = sub(basename(assembly),"\\..*","")

  command <<<
    assembly_to_variants.sh \
    -s ~{accession} \
    -a ~{assembly}

    mv snpEff_summary.html ~{accession}.snpEff_summary.html
  >>>

  output {
    File annotated_vcf = "~{accession}.ann.vcf.gz"
    File annotated_vcf_index = "~{accession}.ann.vcf.gz.tbi"
    File snpEff_summary = "~{accession}.snpEff_summary.html"
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/assembly_to_variants:latest"
    cpu: 1
    memory: "3.75 GB"
    disks: "local-disk 50 HDD"
  }
}
