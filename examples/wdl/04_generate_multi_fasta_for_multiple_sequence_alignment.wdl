version 1.0

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
    docker: "gcr.io/dnastack-pub-container-store/dnastack-cli:latest"
  }
}
task generate_multi_fasta {
  input {
    Array[File] to_concat
    String output_file_name = "joined.txt"
  }

  command <<<
    touch ~{output_file_name}
    while read -r to_concat || [[ -n "$to_concat" ]]; do
    cat "$to_concat" >> ~{output_file_name}
    done < ~{write_lines(to_concat)}
  >>>

  output {
    File concatted_file = output_file_name
  }

  runtime {
    docker: "ubuntu:latest"
  }
}

task do_multiple_sequence_alignment {
  input {
    File multi_fasta
  }

  Int threads = 4

  command <<<
    echo "Gerating sequence alignment from multi-fasta"
    clustalo \
    --infile ~{multi_fasta} \
    --threads ~{threads} \
    --outfile alignment.fasta
  >>>

  output {
    File multiple_alignment = "alignment.fasta"
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/clustal_omega:1.2.4"
    cpu: threads
    memory: "8 GB"
  }
}

workflow download_and_concat {
  input {
    String collection_name
    String collections_api_url = "https://viral.ai/api/collections"
    Int limit = 10
  }

  call download_fastas {
    input:
      collections_api_url = collections_api_url,
      collection_name = collection_name,
      limit = limit
  }

  call generate_multi_fasta {
    input:
      to_concat = download_fastas.downloaded_data
  }

  call do_multiple_sequence_alignment {
    input:
      multi_fasta = generate_multi_fasta.concatted_file
  }

  output {
    Array[File] downloaded_data = download_fastas.downloaded_data
    File concatted_file = generate_multi_fasta.concatted_file
    File multiple_alignment = do_multiple_sequence_alignment.multiple_alignment
  }
}
