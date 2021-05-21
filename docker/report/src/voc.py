# B.1.1.7 from https://cov-lineages.org/global_report_B.1.1.7.html
# UK variant
# Criteria: 5/17
B117 = {
    3265: 'T1001I',
    5386: 'A1708D',
    6952: 'I2230T',
    11288: 'del9',
    21765: 'del6',
    21991: 'del3',
    23062: 'N501Y',
    23269: 'A570D',
    23602: 'P681H',
    23707: 'T716I',
    24505: 'S982A',
    24913: 'D1118H',
    27971: 'Q27stop',
    28109: 'Y73C',
    28279: 'D3L',
    28975: 'S235F'
}


# B.1.351 set from https://cov-lineages.org/global_report_B.1.351.html
# Criteria: 5/9
B1351 = {
    28885: 'P71L',
    26454: 'T205I',
    5227: 'K1655N',
    21799: 'D80A',
    22204: 'D215G',
    22810: 'K417N',
    23662: 'A701V',
    23062: 'N501Y',
    23011: 'E484K'
}

# P.1 from https://cov-lineages.org/global_report_P.1.html
# Criteria: 10/19
P1 = {
    3826: 'S1188L',
    5647: 'K1795Q',
    11288: 'del',
    21613: 'L18F',
    21619: 'T20N',
    21637: 'P26S',
    21973: 'D138Y',
    22129: 'R190S',
    22810: 'K417T',
    28011: 'E484K',
    23062: 'N501Y',
    23524: 'H655Y',
    24640: 'T1027I',
    25911: 'G174C',
    28166: 'E92K',
    28510: 'P80R'
}

# Evolving sites from https://www.biorxiv.org/content/10.1101/2020.12.31.425021v1
bloom = {
    23402: 'D614G',
    23011: 'E484',
    22927: 'F456',
    23017: 'F486',
    23029: 'F490',
    22897: 'G446',
    22900: 'G447',
    23014: 'G485',
    23047: 'G496',
    22975: 'I472',
    22891: 'K444',
    22924: 'L455',
    22903: 'N448',
    22909: 'N450',
    22711: 'P384',
    22708: 'S383',
    22888: 'S443',
    22894: 'V445',
    22654: 'Y365',
    22666: 'Y369',
    22906: 'Y449',
    22978: 'Y473'
}


VOCS = {}
VOCS.update(B117)
VOCS.update(B1351)
VOCS.update(P1)
VOCS.update(bloom)


def covid_watch(sample_variants: list):
    b117_raw_score  = sum([variant in B117 for variant in sample_variants])
    b1351_raw_score = sum([variant in B1351 for variant in sample_variants])
    P1_raw_score    = sum([variant in P1 for variant in sample_variants])
    other_raw_score = sum([variant in bloom for variant in sample_variants])
    return b117_raw_score, b1351_raw_score, P1_raw_score, other_raw_score
