import numpy as np
import pandas as pd
import pycountry_convert as pc

from datetime import datetime, timedelta


from voc import B117, B1351, P1


country_fix_dict = {
    'USA': 'United States',
    'Quebec': 'Canada',
    'North America / Canada / British Columbia': 'Canada',
    'North America / Canada / Ontario': 'Canada',
    'North America / Canada / British Columbia': 'Canada',
    'North America / Canada / Quebec': 'Canada',
    'North America / Canada / Ontario / Toronto': 'Canada',
    'North America / Canada / Manitoba': 'Canada',
    'North America / Canada / Nova Scotia': 'Canada',
    'North America / Canada / Ontario / Ottawa': 'Canada',
    'North America / Canada / New Brunswick': 'Canada',
    'North America / Canada / Ontario / Brampton': 'Canada',
    'North America / Canada / Newfoundland and Labrador': 'Canada',
    'North America / Canada': 'Canada',
    'North America / Canada / British Columbia / Abbotsford': 'Canada',
    'North America / Canada / Alberta': 'Canada',
    'Viet nam': 'Vietnam',
    'West Bank': 'Palestine',
    'Timor-Leste': np.nan
}


def country_to_continent(country_name):
    country_alpha2 = pc.country_name_to_country_alpha2(country_name)
    country_continent_code = pc.country_alpha2_to_continent_code(country_alpha2)
    country_continent_name = pc.convert_continent_code_to_continent_name(country_continent_code)
    return country_continent_name


def clean_search_data(variant_df, meta_df, annotation_df):
    # Fixing meta data; remove covseq and na data
    meta_df.location = meta_df.location.dropna().apply(lambda x: x.split(':')[0]).replace(country_fix_dict)
    meta_df = meta_df[meta_df.location.notna()]

    # Re-alligning variant_df with meta_df
    unique_accessions = set(meta_df.accession.values) & set(variant_df.sequence_accession.values)
    variant_df = variant_df[variant_df.sequence_accession.isin(unique_accessions)]
    meta_df = meta_df[meta_df.accession.isin(unique_accessions)]

    # Making time weekly
    meta_df.release_date = meta_df.release_date.astype('datetime64').apply(lambda x: (x - timedelta(days=x.dayofweek)))
    meta_df['continent'] = meta_df.location.apply(country_to_continent)

    return variant_df, meta_df, annotation_df


def format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date, exclude_lineage=False, exclude_variant=False):
    d = format_end_date(variant_df, meta_df, end_date)
    d = format_start_date(*d, start_date)
    d = format_location(*d, location)
    d = format_lineage(*d, lineage, exclude_lineage)
    d = format_variant(*d, variant, exclude_variant)
    return d


def format_lineage(variant_df, meta_df, lineage, exclude=False):
    if exclude:
        if lineage == 'All':
            return pd.DataFrame(columns=meta_df.columns), pd.DataFrame(columns=meta_df.columns)
        else:
            accessions = meta_df[meta_df.lineage != lineage].accession.unique()
            return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]
    else:
        if lineage == 'All':
            return variant_df, meta_df
        else:
            accessions = meta_df[meta_df.lineage == lineage].accession.unique()
            return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]


def format_variant(variant_df, meta_df, variant, exclude=False):
    if exclude:
        if variant == 'All':
            return pd.DataFrame(columns=meta_df.columns), pd.DataFrame(columns=meta_df.columns)
        else:
            accessions = variant_df[variant_df.start_position == variant].sequence_accession.unique()
            return variant_df[~variant_df.sequence_accession.isin(accessions)], meta_df[~meta_df.accession.isin(accessions)]
    else:
        if variant == 'All':
            return variant_df, meta_df
        else:
            accessions = variant_df[variant_df.start_position == variant].sequence_accession.unique()
            return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]


def format_location(variant_df, meta_df, location):
    if location == 'All':
        return variant_df, meta_df

    else:
        accessions = meta_df[meta_df.location == location].accession.unique()
        return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]


def format_dataset(variant_df, meta_df, dataset, exclude=False):
    if exclude:
        if dataset == 'All':
            return pd.DataFrame(columns=meta_df.columns), pd.DataFrame(columns=meta_df.columns)
        elif dataset in ['B.1.1.7', 'B.1.351', 'P.1']:
            accessions = meta_df[meta_df.lineage != dataset].accession.unique()
            return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]
        elif dataset in [23402, 23062]:
            accessions = variant_df[variant_df.start_position == dataset].sequence_accession.unique()
            return variant_df[~variant_df.sequence_accession.isin(accessions)], meta_df[~meta_df.accession.isin(accessions)]
    else:
        if dataset == 'All':
            return variant_df, meta_df
        elif dataset in ['B.1.1.7', 'B.1.351', 'P.1']:
            accessions = meta_df[meta_df.lineage == dataset].accession.unique()
            return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]
        elif dataset in [23402, 23062]:
            accessions = variant_df[variant_df.start_position == dataset].sequence_accession.unique()
            return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]


def format_start_date(variant_df, meta_df, start_date):

    if start_date == 'All':
        return variant_df, meta_df

    else:
        start_date = datetime.strptime(str(start_date), '%Y-%m-%d')
        accessions = meta_df[meta_df.release_date >= start_date].accession.unique()
        return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]


def format_end_date(variant_df, meta_df, end_date):

    if end_date == 'All':
        return variant_df, meta_df

    else:
        end_date = datetime.strptime(str(end_date), '%Y-%m-%d')
        accessions = meta_df[meta_df.release_date <= end_date].accession.unique()
        return variant_df[variant_df.sequence_accession.isin(accessions)], meta_df[meta_df.accession.isin(accessions)]


def annotate(x, x1, x2, names, null):
    name = names[(x >= x1) & (x < x2)]
    if name.size:
        return name[0]
    else:
        return null
