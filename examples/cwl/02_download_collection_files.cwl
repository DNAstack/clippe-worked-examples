#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
requirements:
  ShellCommandRequirement: {}
  InlineJavascriptRequirement: {}
hints:
  DockerRequirement:
    dockerPull: gcr.io/dnastack-pub-container-store/dnastack-cli:latest
inputs:
  collection_name:
    type: string?
    default: "NCBI SRA SARS-CoV-2 Genomes"
  collections_api_url:
    type: string?
    default: "https://viral.ai/api/collections"
  limit:
    type: string?
    default: "10"
arguments:
  - shellQuote: false
    valueFrom: >
      mkdir outputs
      dnastack config set collections.url "${inputs.collections_api_url}"
      collection_slug_name=$(dnastack collections list | jq -r '.[] | select(.name == "${inputs.collection_name}") | .slugName')
      query="SELECT drs_url FROM \"viralai\".\"$collection_slug_name\".\"files\" LIMIT ${inputs.limit}"
      dnastack collections query $collection_slug_name "$query" | jq -r '.[].drs_url' | dnastack files download -o outputs
outputs:
  output:
    type:
      type: array
      items: File
    outputBinding:
      glob: "outputs/*"
