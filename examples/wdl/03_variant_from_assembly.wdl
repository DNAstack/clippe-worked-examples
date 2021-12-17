version 1.0

workflow variants_from_assembly {
  input {
    String collection_name = "NCBI SRA SARS-CoV-2 Genomes"
    String collections_api_url = "https://viral.ai/api/collections"
    String limit = "10"
    String reference_genome_id = "NC_045512"
  }

  call download_fastas {
    input:
      collections_api_url = collections_api_url,
      collection_name = collection_name,
      limit = limit
  }

  call download_reference {
    input:
      reference_genome_id = reference_genome_id
  }

  scatter (assembly in download_fastas.downloaded_data) {
    call call_variants {
      input:
        assembly = assembly,
        reference_fasta = download_reference.reference_fasta,
        reference_genome_id = reference_genome_id
    }
  }

  output {
    Array[File] vcf = call_variants.vcf
    Array[File] vcf_index = call_variants.vcf_index
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

    find outputs -type f -exec mv {} outputs/ \;
  >>>

  output {
    Array[File] downloaded_data = glob("outputs/*")
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/dnastack-cli:latest"
  }
}

task download_reference {
  input {
    String reference_genome_id
  }

  command <<<
    curl -X GET \
      $"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=~{reference_genome_id}&rettype=fasta&retmode=text" \
        -o ~{reference_genome_id}.fasta
  >>>

  output {
    File reference_fasta = "${reference_genome_id}.fasta"
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/assembly_to_variants:latest"
  }
}

task call_variants {
  input {
    File assembly
    File reference_fasta
    String reference_genome_id
  }

  String accession = sub(basename(assembly),"\\..*","")

  command <<<
    assembly_to_variants.sh \
      -s ~{accession} \
      -a ~{assembly} \
      -g ~{reference_genome_id} \
      -r ~{reference_fasta}
  >>>

  output {
    File vcf = "~{accession}.vcf.gz"
    File vcf_index = "~{accession}.vcf.gz.tbi"
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/assembly_to_variants:latest"
    cpu: 1
    memory: "3.75 GB"
    disks: "local-disk 50 HDD"
  }
}
