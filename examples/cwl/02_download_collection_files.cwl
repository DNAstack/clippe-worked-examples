#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow

requirements:
    - class: InlineJavascriptRequirement
    - class: ShellCommandRequirement

inputs:
  collection_name:
    type: string?
    default: "NCBI SRA SARS-CoV-2 Genomes"
  collections_api_url:
    type: string?
    default: "https://viral.ai/api/collections"
  limit:
    type: int?
    default: 10

steps:
  get_slug_name:
    run: ./tools/get_slug_name.cwl
    in:
      collection_name: collection_name
      collections_api_url: collections_api_url
    out: [ slug_name ]
  download_files:
    run: ./tools/download_files.cwl
    in:
      collections_api_url: collections_api_url
      collection_slug_name: get_slug_name/slug_name
      limit: limit
    out: [ downloaded_files ]

outputs:
  downloaded_files:
    type:
      type: array
      items: File
    outputSource: download_files/downloaded_files
