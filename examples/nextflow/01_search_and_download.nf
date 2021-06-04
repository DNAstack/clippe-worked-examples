#!/usr/bin/env nextflow

params.lineage="B.1.1.7"
params.search_api = "https://collection-service.publisher.dnastack.com/collection/library/search/"
query = """SELECT \
    drs_url \
FROM covid.cloud.sequences seq \
JOIN covid.cloud.files files on files.sequence_accession = seq.accession \
WHERE lineage = '${params.lineage}' AND files.type = 'Assembly' \
LIMIT 10"""

process submitQueryAndDownload {
    container 'gcr.io/dnastack-pub-container-store/dnastack-client-library:latest'
    containerOptions = '--user root'

    output:
    file 'out/*' into searchOutput

    script:
    """
    #!/usr/bin/env bash
    mkdir out
    dnastack config set data-connect-url ${params.search_api}
    dnastack dataconnect query -r "${query}" |  dnastack files download -o out
    """
}


searchOutput.flatMap().subscribe { println "File: ${it.name}" }