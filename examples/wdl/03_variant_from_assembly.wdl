version 1.0

workflow variants_from_assembly {
	input {
        String collection_name
        String data_connect_url = "https://collection-service.staging.dnastack.com/collection/library/data-connect/"
        String collection_url = "https://collection-service.staging.dnastack.com/collections"
        String drs_url = "https://collection-service.staging.dnastack.com/collection/library/drs/objects"
    }

    call download_fastas {
        input: 
            collection_name = collection_name,
            data_connect_url = data_connect_url,
            collection_url = collection_url,
            drs_url = drs_url
    }
    

    scatter (fasta in download_fastas.fastas) {
        call call_variants {
                input:
                    assembly = fasta
            }
    }


	output {
		Array[File] annotated_vcf = call_variants.annotated_vcf
		Array[File] annotated_vcf_index = call_variants.annotated_vcf_index
		Array[File] snpEff_summary = call_variants.snpEff_summary
	}
}

task download_fastas {

    input {
        String collection_name
        String data_connect_url
        String collection_url
        String drs_url
    }

    command <<<
        dnastack config set data-connect-url "~{data_connect_url}"
        dnastack config set collections-url "~{collection_url}"
        mkdir outputs
        query=$(dnastack collections list | jq -r '.[] | select(.name == "~{collection_name}") | .itemsQuery' | sed -e 's:/\*[^*]*\*/::g' )
        for drs_object in $(dnastack dataconnect query "${query} LIMIT 10" | jq -c '.[] | select(.type == "blob") |{id:.id,name:.name}'); do
            drs_id="$(echo ${drs_object} | jq -r '.id')"
            drs_name="$(echo ${drs_object} | jq -r '.name' | sed 's:/:_:g')"
            echo "downloading data from ~{drs_url}/${drs_id}"
            url=$(curl "~{drs_url}/${drs_id}/access/https" | jq -r '.url')
            mkdir outputs/${drs_id}
            wget -O outputs/${drs_id}/${drs_name} "${url}" || true
        done
    >>>

    output {
        Array[File] fastas = glob("outputs/*/*")
    }

    runtime {
        docker: "gcr.io/dnastack-pub-container-store/dnastack-cli:latest"
    }
}

task call_variants {
	input {
		File assembly	
    }

    String accession = sub(basename(assembly),"\\..*","")

	command <<<
		assembly_to_variants.sh \
			-s ~{accession} \
			-a ~{assembly}

		mv snpEff_summary.html ~{accession}.snpEff_summary.html
	>>>

	output {
		File annotated_vcf = "~{accession}.ann.vcf.gz"
		File annotated_vcf_index = "~{accession}.ann.vcf.gz.tbi"
		File snpEff_summary = "~{accession}.snpEff_summary.html"
	}

	runtime {
		docker: "gcr.io/dnastack-pub-container-store/assembly_to_variants:latest"
		cpu: 1
		memory: "3.75 GB"
		disks: "local-disk 50 HDD"
	}
}