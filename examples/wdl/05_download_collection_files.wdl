version 1.0

task download_files {

  input {
    String collection_name
    String collection_url
    String drs_url
  }

  command <<<
    function downloadDRS() {
      local drs_id="$1"
      local accessURL="$(curl ~{drs_url}/ga4gh/drs/v1/objects/${drs_id}/access/https | jq -r '.url')"

      echo "downloading data from ~{drs_url}/ga4gh/drs/v1/objects/${drs_id}"
      mkdir -p outputs/${drs_id}
      wget -O outputs/${drs_id}.txt "${accessURL}"
    }

    dnastack config set collections-url "~{collection_url}"

    itemsQuery="$(dnastack collections list | jq -r ".[] | select(.name == \"~{collection_name}\") | .itemsQuery")"
    filesQuery="WITH items AS (${itemsQuery}) SELECT id FROM items WHERE type = 'blob'"

    drs_ids="$(dnastack collections query library "${filesQuery}" | jq -r '.[].id')"
    for drs_id in ${drs_ids}; do
      downloadDRS ${drs_id}
    done
  >>>

  output {
    Array[File] downloaded_data = glob("outputs/*")
  }

  runtime {
    docker: "gcr.io/dnastack-pub-container-store/dnastack-cli:latest"
  }
}

task concat_files {
  input {
    Array[File] to_concat
    String output_file_name = "joined.txt"
  }

  command <<<
    cat ~{sep=" " to_concat} > ~{output_file_name}
  >>>

  output {
    File concatted_file = output_file_name
  }

  runtime {
    docker: "ubuntu:latest"
  }
}

workflow download_and_concat {
  input {
    String collection_name
    String explorer_url = "https://explorer.dnastack.com"
  }

  call download_files {
    input:
      collection_name = collection_name,
      collection_url = explorer_url + "/api/collections",
      drs_url = explorer_url
  }

  call concat_files {
    input:
      to_concat = download_files.downloaded_data
  }

  output {
    Array[File] downloaded_data = download_files.downloaded_data
    File concatted_file = concat_files.concatted_file
  }
}
