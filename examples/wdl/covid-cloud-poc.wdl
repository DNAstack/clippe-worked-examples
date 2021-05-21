version 1.0

struct DrsFiles {
    Array[String] files
    Int size
}

struct DownloadShard {
    String index
    DrsFiles fasta
    DrsFiles vcf
    DrsFiles vcf_index
}


task get_data {

    input {
        Int limit
        Int shard_size
        Array[String] where_clauses
    }

    command <<<
        query="$(cat <<EOF
        SELECT * FROM (SELECT 
            accession,
            sequence_length,
            host,
            isolation_source,
            location,
            collection_date,
            release_date,
            data_source,
            nucleotide_completeness,
            sample_accession,
            lineage,
            lineage_confidence,
            (SELECT CAST(ROW(drs_url,size) AS ROW(drs_url VARCHAR, size INTEGER)) as drs FROM covid.cloud.files WHERE sequence_accession = s.accession and type = 'Assembly') as fasta_file,
            (SELECT CAST(ROW(drs_url,size) AS ROW(drs_url VARCHAR, size INTEGER)) as drs FROM covid.cloud.files WHERE sequence_accession = s.accession and type = 'Variants') as vcf_file,
            (SELECT CAST(ROW(drs_url,size) AS ROW(drs_url VARCHAR, size INTEGER)) as drs FROM covid.cloud.files WHERE sequence_accession = s.accession and type = 'Variants Index') as vcf_index_file
        FROM covid.cloud.sequences s
        WHERE
            ~{sep=" AND " where_clauses}
        )
        WHERE
            vcf_file IS NOT NULL
            AND fasta_file IS NOT NULL
            AND vcf_index_file IS NOT NULL
            AND nucleotide_completeness = 'complete'
        LIMIT ~{limit}
        EOF
        )"

        echo "${query}"
        ~/.covid-cloud/covid-cloud search query "${query}" > search-output.json
        python3 <<CODE
        import json

        with open("search-output.json") as sofp:
            so = json.load(sofp)
        fasta = []
        vcf = []
        vcf_index = []
        file_index = 0
        shards = []
        index=0
        for i,sequence in enumerate(so):
            if i != 0 and i % ~{shard_size} == 0:
                shards.append({
                    "index":str(index),
                    "fasta": {
                        "size": sum(f[0] for f in fasta),
                        "files": [f[1] for f in fasta]
                    },

                    "vcf": {
                        "size": sum(f[0] for f in vcf),
                        "files": [f[1] for f in vcf]
                    },

                    "vcf_index": {
                        "size": sum(f[0] for f in vcf_index),
                        "files": [f[1] for f in vcf_index]
                    }
                })
                fasta = []
                vcf = []
                vcf_index = []
                index = index + 1
            else:
                fasta.append([sequence["fasta_file"]["size"],sequence["fasta_file"]["drs_url"]])
                vcf.append([sequence["vcf_file"]["size"],sequence["vcf_file"]["drs_url"]])
                vcf_index.append([sequence["vcf_index_file"]["size"],sequence["vcf_index_file"]["drs_url"]])
        if fasta and vcf and vcf_index:
            shards.append({
                "index":str(index),
                "fasta": {
                    "size": sum(f[0] for f in fasta),
                    "files": [f[1] for f in fasta]
                },

                "vcf": {
                    "size": sum(f[0] for f in vcf),
                    "files": [f[1] for f in vcf]
                },

                "vcf_index": {
                    "size": sum(f[0] for f in vcf_index),
                    "files": [f[1] for f in vcf_index]
                }
            })
        with open("download_shards.json","w") as dlshards:
            json.dump(shards,dlshards,indent=2)
        CODE
    >>>

    output {
        File search_output = "search-output.json"
        File download_shards = "download_shards.json"
    }
    

    runtime {
        docker: "covid-cloud:latest"
    }
}

task download_data {

    input {
        DownloadShard shard
    }
    
    command <<<
        echo "downloading  files"
        mkdir fasta
        ~/.covid-cloud/covid-cloud files download -o fasta ~{sep=" " shard.fasta.files}
        ~/.covid-cloud/covid-cloud files download -o . ~{sep=" " shard.vcf.files}
        ~/.covid-cloud/covid-cloud files download -o . ~{sep=" " shard.vcf_index.files}
    >>>
    
    output {
        Array[File] fasta_files = glob("fasta/*")
        Array[File] vcf_files = glob("*.vcf.gz")
        Array[File] vcf_index_files = glob("*.vcf.gz.tbi")
    }


    runtime {
        cpu: 1
        disks: "local-disk " + ((ceil((shard.vcf.size + shard.vcf_index.size + shard.fasta.size)/1000000000) + 10) * 2) + " HDD"
        memory: "7.5GB"
        docker: "covid-cloud:latest"
    }
}

task get_stats {

    input {
        DownloadShard shard
        Array[File] vcf_files
        Array[File] vcf_index_files
    }
    
    command <<<
        mkdir plots
        mkdir stats
        for vcf_file in $(echo "~{sep='\" \"' vcf_files}"); do
            filename="$(basename ${vcf_file}).stats"
            tmp=$(mktemp -d)
            bcftools stats ${vcf_file} > "stats/${filename}"
            plot-vcfstats -p ${tmp} -s -T "Vcf Stats" "stats/${filename}"
            mv ${tmp}/summary.pdf "plots/$(basename ${vcf_file}).summary.pdf"
        done
        tar -czvf "summary-plots.~{shard.index}.tar.gz" plots
        tar -czvf "stats.~{shard.index}.tar.gz" stats
    >>>
    
    output {
        File stats_gz = "stats.~{shard.index}.tar.gz"
        File summary_gz = "summary-plots.~{shard.index}.tar.gz"
    }

    runtime {
        cpu: 1
        memory: "3 GB"
        docker: "htslib:latest"
    }
}

task merge_and_generate_plots {

    input {
        Array[File] vcf_files
        Array[File] vcf_index_files
    }

    
    command <<<
        mkdir plots
        bcftools merge -O b -o merged.vcf.gz  ~{sep=" " vcf_files} 
        tabix -p vcf merged.vcf.gz
        bcftools stats merged.vcf.gz > merged.vcf.gz.stats
        plot-vcfstats -p plots -s -T "Vcf Stats" merged.vcf.gz.stats
    >>>
    
    output {
        File multi_sample_vcf = "merged.vcf.gz"
        File multi_sample_vcf_index = "merged.vcf.gz.tbi"
        File multi_sample_stats = "merged.vcf.gz.stats"
        File summary = "plots/summary.pdf"  
    }

    runtime {
        docker: "htslib:latest"
    }
}

task produce_report {
    input {
        Array[File] vcf_files
        Array[File] vcf_index_files
        File search_output
        File lineage
    }

    command <<<
        python3 <<CODE
        import sys
        import pandas as pd
        import numpy as np
        from pysam import VariantFile
        import os
        import json

        sys.path.append("/reports")

        import plot as pl
        import utils

        lineage_df = pd.read_csv("~{lineage}")[["taxon","lineage"]]
        lineage_df["accession"] = lineage_df["taxon"]
        lineage_df.drop(["accession"],axis=1)
        with open("~{search_output}") as jf:
            sequence_file = json.load(jf)
            meta_json = {}
            for e in sequence_file:
                for k,v in e.items():
                    if k not in meta_json:
                        meta_json[k] = []
                    meta_json[k].append(v)
            meta_df = pd.DataFrame(meta_json,columns=meta_json.keys())

        lineage_df = lineage_df.set_index("accession")
        meta_df = meta_df.set_index("accession")
        meta_df.update(lineage_df)
        meta_df.reset_index(inplace=True)

        variants = "~{sep=' ' vcf_files}".split()
        annotation_df = pd.read_csv("/reports/annotations.csv")
        with open("variants.csv", "w") as variants_file_handle:
            variants_file_handle.write("{}".format(",".join(["reference_bases","start_position","stop_position","alternate_bases","sequence_accession"])))
            for vcf_path in variants:
                print("Loading Variants for file " + vcf_path)
                vcf_file = VariantFile(vcf_path)
                for record in vcf_file.fetch():
                    for alt in record.alts:
                        if alt:
                            variants_file_handle.write(f"\n{record.ref},{record.start},{record.stop},{alt},{record.samples[0].name}")
        variants_df = pd.read_csv("variants.csv")
        variants_df,meta_df,annotation_df = utils.clean_search_data(variants_df,meta_df,annotation_df)
        pl.plot_geo_search(variants_df, meta_df, annotation_df).write_image("geo.pdf")
        pl.plot_needle_search(variants_df, meta_df, annotation_df).write_image("needle.pdf")
        pl.plot_analysis_search(variants_df, meta_df, annotation_df).write_image("analysis.pdf")
        pl.plot_corr_search(variants_df, meta_df, annotation_df).write_image("correlation.pdf")
        pl.plot_location_search(variants_df, meta_df, annotation_df).write_image("location.pdf")
        pl.plot_lineage_search(variants_df, meta_df, annotation_df).write_image("lineage.pdf")
        pl.plot_continent_search(variants_df, meta_df, annotation_df).write_image("continent.pdf")
        pl.plot_voc_table_search(variants_df, meta_df, annotation_df).write_image("voc.pdf")
        pl.plot_lineage_table_search(variants_df, meta_df, annotation_df).write_image("lineage_table.pdf")
        CODE
    >>>

    output {
        Array[File] reports = glob("*.pdf")
    }

    runtime {
        docker: "reports:latest"
        cpu: 1
        memory: "7.5 GB"
    }
}




task lineage_assignment {

	input {
		Array[File] assemblies
	}

	Int threads = 1

	command {
        cat ~{sep=" " assemblies} > multi_sample.fa
        pangolin \
            --threads ~{threads} \
            --outfile multi_sample.lineage.csv \
            multi_sample.fa
	}

	output {
		File lineage_metadata = "multi_sample.lineage.csv"
	}

	runtime {
		docker: "gcr.io/cool-benefit-817/pangolin:a1f8a3a"
		cpu: threads
		memory: "7.5 GB"
	}
}

workflow do_stuff {

    input {
        Array[String] search_criteria
        Int? limit
        Int? shard_size
    }

    call get_data {
        input: where_clauses = search_criteria, limit = select_first([limit,10]), shard_size = select_first([shard_size,500])
    }

    Array[DownloadShard] download_shards = read_json(get_data.download_shards)

    scatter(shard in download_shards){
        call download_data {
            input: shard = shard
        }
        call get_stats {
            input: vcf_files = download_data.vcf_files, vcf_index_files = download_data.vcf_index_files, shard = shard
        }
    }

    Array[File] fasta_files = flatten(download_data.fasta_files)
    Array[File] vcf_files = flatten(download_data.vcf_files)
    Array[File] vcf_index_files = flatten(download_data.vcf_index_files)

    call merge_and_generate_plots {
        input: vcf_files = vcf_files, vcf_index_files = vcf_index_files
    }

    call lineage_assignment {
        input: assemblies = fasta_files
    }

    call produce_report {
        input: vcf_files = vcf_files, vcf_index_files = vcf_index_files, search_output = get_data.search_output, lineage = lineage_assignment.lineage_metadata
    }

    output {
        File multi_sample_vcf_summary = merge_and_generate_plots.summary
        Array[File] sharded_per_sample_vcf_summary = get_stats.summary_gz
        Array[File] sharded_per_sample_vcf_stats = get_stats.stats_gz
        File lineage_metadata = lineage_assignment.lineage_metadata
        Array[File] reports = produce_report.reports
    }
}