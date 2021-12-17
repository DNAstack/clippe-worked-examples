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
  collection_name:
      type: string
  collections_api_url:
      type: string

baseCommand: [/bin/bash, -c]
arguments:
  - valueFrom: >
      dnastack config set collections.url "$(inputs.collections_api_url)";
      dnastack collections list | jq -r '.[] | select(.name == "$(inputs.collection_name)") | .slugName' | tr -d '\\n' > slug_name.txt

outputs:
  slug_name:
      type: string
      outputBinding:
          glob: slug_name.txt
          loadContents: true
          outputEval: $(self[0].contents)

