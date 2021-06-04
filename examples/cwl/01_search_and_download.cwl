#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
requirements:
  ShellCommandRequirement: {}
  InlineJavascriptRequirement: {}
hints:
  DockerRequirement:
    dockerPull: gcr.io/dnastack-pub-container-store/dnastack-client-library:latest
inputs:
  search_api:
    type: string?
    default: "https://collection-service.publisher.dnastack.com/collection/library/search/"
  query:
    type: string?
    default: "SELECT drs_url FROM covid.cloud.sequences seq JOIN covid.cloud.files files on files.sequence_accession = seq.accession WHERE lineage = 'B.1.1.7' AND files.type = 'Assembly' LIMIT 10"
arguments:
  - shellQuote: false
    valueFrom: >
      mkdir out

      dnastack config set data-connect-url $(inputs.search_api)

      dnastack dataconnect query -r "$(inputs.query)" |  dnastack files download -o out
outputs:
  output:
    type:
      type: array
      items: File
    outputBinding:
      glob: "out/*"
