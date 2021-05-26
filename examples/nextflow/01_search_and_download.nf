#!/usr/bin/env nextflow

params.lineage="B.1.1.7"
params.search_api = "https://search.international.covidcloud.ca/"
query = """SELECT \
    drs_url \
FROM covid.cloud.sequences seq \
JOIN covid.cloud.files files on files.sequence_accession = seq.accession \
WHERE lineage = '${params.lineage}' AND files.type = 'Assembly' \
LIMIT 10"""

process submitQueryAndDownload {
    container 'gcr.io/dnastack-pub-container-store/clippe:latest'
    containerOptions = '--user root'

    output:
    file 'out/*' into searchOutput

    script:
    """
    #!/usr/bin/env bash
    mkdir out
    clippe config search-url ${params.search_api}
    clippe search query -r "${query}" |  clippe files download -o out
    """
}


searchOutput.flatMap().subscribe { println "File: ${it.name}" }