#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
requirements:
  ShellCommandRequirement: {}
  InlineJavascriptRequirement: {}
hints:
  DockerRequirement:
    dockerPull: dnastack/clippe:latest
inputs:
  search_api:
    type: string?
    default: "https://search.international.covidcloud.ca/"
  query:
    type: string?
    default: "SELECT drs_url FROM covid.cloud.sequences seq JOIN covid.cloud.files files on files.sequence_accession = seq.accession WHERE lineage = 'B.1.1.7' AND files.type = 'Assembly' LIMIT 10"
arguments:
  - shellQuote: false
    valueFrom: >
      mkdir out

      mkdir ~/.clippe

      clippe config search-url $(inputs.search_api)

      clippe search query -r "$(inputs.query)" |  clippe files download -o out
outputs:
  output:
    type:
      type: array
      items: File
    outputBinding:
      glob: "out/*"
