import sys
import pandas as pd
import numpy as np
from pysam import VariantFile
import os
import plot as pl

def run():
    sequence_file = sys.argv[1]
    variants = sys.argv[1:]
    annotation_df = pd.read_csv("/report/annotation.csv")
    meta_df = pd.read_json(sequence_file)
    for vcf_path in variants:
        print("Loading Variants for file " + vcf_path)
        vcf_file = VariantFile(vcf_path)
        rows = {"ref":[],"start":[],"stop":[],"alt":[],"sample":[]}
        for record in vcf_file.fetch():
            for alt in record.alts:
                rows["reference_bases"].append(record.ref)
                rows["start_position"].append(record.start)
                rows["stop_position"].append(record.stop)
                rows["sequence_accession"].append(record.samples[0].name)
                rows["alternate_bases"].append(alt)
        variants_df.append(pd.DataFrame(rows),ignore_index=True)              
        
    pl.plot_geo_search(variant_df, meta_df, annotation_df).write_image("geo.pdf")
    pl.plot_needle_search(variant_df, meta_df, annotation_df).write_image("needle.pdf")
    pl.plot_analysis_search(variant_df, meta_df, annotation_df).write_image("analysis.pdf")
    pl.plot_corr_search(variant_df, meta_df, annotation_df).write_image("correlation.pdf")
    pl.plot_location_search(variant_df, meta_df, annotation_df).write_image("location.pdf")
    pl.plot_lineage_search(variant_df, meta_df, annotation_df).write_image("lineage.pdf")
    pl.plot_continent_search(variant_df, meta_df, annotation_df).write_image("continent.pdf")
    pl.plot_voc_table_search(variant_df, meta_df, annotation_df).write_image("voc.pdf")
    pl.plot_lineage_table_search(variant_df, meta_df, annotation_df).write_image("lineage_table.pdf")
    


if __name__ == "__main__":
    run()