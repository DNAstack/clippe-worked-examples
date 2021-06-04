version 1.0

task submit_query_and_download {
    input {
        String query
        String search_api
    }
    command <<<
        mkdir out
        dnastack config set data-connect-url ~{search_api}
        dnastack config list
        dnastack dataconnect query -r "~{query}" |  dnastack files download -o out
    >>>

    output {
        Array[File] downloads = glob("out/*")
    }
    runtime {
        docker: "gcr.io/dnastack-pub-container-store/dnastack-client-library:latest"
    }
}

workflow download_assemblies_for_lineage {
    input {
        String lineage = "B.1.1.7"
        String search_api = "https://collection-service.publisher.dnastack.com/collection/library/search/"
        Int limit = 10
    }

    String query = "SELECT drs_url FROM covid.cloud.sequences seq " +
                   "JOIN covid.cloud.files files on files.sequence_accession = seq.accession " +
                   "WHERE lineage = '~{lineage}' AND files.type = 'Assembly' " +
                   "LIMIT ~{limit}"

    call submit_query_and_download {
        input: query = query, search_api = search_api
    }

    output {
        Array[File] downloads = submit_query_and_download.downloads
    }
}