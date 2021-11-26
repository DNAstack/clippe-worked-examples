version 1.0

task download_files {

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
    docker: "gcr.io/dnastack-pub-container-store/dnastack-cli:v0.3.4"
  }
}

workflow download_first_ten_files {
  input {
    String collection_name
    String collections_api_url = "https://viral.ai/api/collections"
  }

  Int limit = 10

  call download_files {
    input:
      collections_api_url = collection_name,
      collection_name = collection_name,
      limit = limit,
  }

  output {
    Array[File] downloaded_data = download_files.downloaded_data
  }
}
