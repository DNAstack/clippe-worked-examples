#!/usr/bin/env nextflow

params.collection_name="NCBI SRA SARS-CoV-2 Genomes"
params.collections_api_url="https://viral.ai/api/collections"
params.limit = "10"

process downloadFirstTenFiles {
    container 'gcr.io/dnastack-pub-container-store/dnastack-cli:v0.3.3'
    containerOptions = '--user root'

    output:
    file 'outputs/*' into downloadOutput

    script:
    """
    #!/usr/bin/env bash
    mkdir outputs
    dnastack config set collections.url "${params.collections_api_url}"
    collection_slug_name=$(dnastack collections list | jq -r '.[] | select(.name == "${params.collection_name}") | .slugName')
    query="SELECT drs_url FROM \"viralai\".\"$collection_slug_name\".\"files\" LIMIT ${params.limit}"
    dnastack collections query $collection_slug_name "$query" | jq -r '.[].drs_url' | dnastack files download -o outputs
    """
}


downloadOutput.flatMap().subscribe { println "File: ${it.name}" }
