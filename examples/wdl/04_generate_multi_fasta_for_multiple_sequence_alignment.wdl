version 1.0

task download_fastas {

    input {
        String collection_name
        String data_connect_url
        String collection_url
        String drs_url
    }

    command <<<
        dnastack config set data-connect-url "~{data_connect_url}"
        dnastack config set collections-url "~{collection_url}"
        mkdir outputs
        query=$(dnastack collections list | jq -r '.[] | select(.name == "~{collection_name}") | .itemsQuery' | sed -e 's:/\*[^*]*\*/::g' )
        for drs_object in $(dnastack dataconnect query "${query}" | jq -c '.[] | select(.type == "blob") |{id:.id,name:.name}'); do
            drs_id="$(echo ${drs_object} | jq -r '.id')"
            drs_name="$(echo ${drs_object} | jq -r '.name' | sed 's:/:_:g')"
            echo "downloading data from ~{drs_url}/${drs_id}"
            url=$(curl "~{drs_url}/${drs_id}/access/https" | jq -r '.url')
            mkdir outputs/${drs_id}
            wget -O outputs/${drs_id}/${drs_name} "${url}" || true
        done
    >>>

    output {
        Array[File] fastas = glob("outputs/*/*")
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
        cat ~{sep=" " to_concat} > ~{output_file_name}
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

    command <<<
        echo "Gerating sequence alignment from multi-fasta"
        echo "perform alignment here" > "alignment.fasta"
    >>>

    output {
        File multiple_alignment = "alignment.fasta"
    }
}

workflow download_and_concat {
    input {
        String collection_name
        String data_connect_url = "https://collection-service.staging.dnastack.com/collection/library/data-connect/"
        String collection_url = "https://collection-service.staging.dnastack.com/collections"
        String drs_url = "https://collection-service.staging.dnastack.com/collection/library/drs/objects"
    }

    call download_files {
        input: 
            collection_name = collection_name,
            data_connect_url = data_connect_url,
            collection_url = collection_url,
            drs_url = drs_url
    }

    call concat_files {
        input: to_concat = download_files.downloaded_data
    }

    output {
        Array[File] downloaded_data = download_files.downloaded_data
        File concatted_file = concat_files.concatted_file
    }
}
