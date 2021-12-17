#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

requirements:
    - class: InlineJavascriptRequirement
    - class: ShellCommandRequirement

hints:
  DockerRequirement:
    dockerPull: gcr.io/dnastack-pub-container-store/dnastack-cli:latest

inputs:
  collections_api_url:
    type: string
  collection_slug_name:
    type: string
  limit:
    type: int

baseCommand: [/bin/bash, -c]
arguments:
  - valueFrom: >
      mkdir outputs;
      dnastack config set collections.url "$(inputs.collections_api_url)";
      dnastack collections query $(inputs.collection_slug_name) "SELECT drs_url FROM \\"viralai\\".\\"$(inputs.collection_slug_name)\\".\\"files\\" WHERE name LIKE '%.fasta' LIMIT $(inputs.limit)" | jq -r '.[].drs_url' | dnastack files download -o outputs

outputs:
  downloaded_files:
    type:
      type: array
      items: File
    outputBinding:
      glob: "outputs/*"
