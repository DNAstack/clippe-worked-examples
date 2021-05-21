import copy
import numpy as np
import pandas as pd
import plotly.figure_factory as ff
import plotly.graph_objects as go
import random
import statsmodels.api as sm

from datetime import date, datetime
from nptyping import NDArray
from plotly.subplots import make_subplots
from scipy.cluster import hierarchy
from scipy.spatial.distance import pdist
from typing import Any, Optional

from style import StyleSheet
from utils import format_search_data, annotate
from voc import B117, B1351, P1


random.seed(2)


def plot_geo_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All'):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
    return plot_geo(meta_df_oi)


def plot_geo(meta_df, title=None):

    # Country df
    country_df = pd.read_csv('https://raw.githubusercontent.com/plotly/datasets/master/2014_world_gdp_with_codes.csv')

    # Merging country and meta DF
    merge_df = pd.merge(meta_df, country_df, left_on='location', right_on='COUNTRY')
    grouped_df = merge_df.groupby(['COUNTRY', 'CODE']).count().accession.reset_index()

    # Title
    title = title or 'Geographical Distribution of COVID Cloud SARS-CoV-2 Samples'

    # Figure
    fig = go.Figure()

    # Plot 1
    fig.add_trace(go.Choropleth(locations=grouped_df['CODE'],
                                z=np.log10(grouped_df['accession']),
                                customdata=grouped_df,
                                hovertemplate="<b>%{customdata[0]}<br>" + \
                                              "%{customdata[2]}" + \
                                              "<extra>%{customdata[1]}</extra>",
                                text=grouped_df['COUNTRY'],
                                colorscale='Blues',
                                autocolorscale=False,
                                reversescale=False,
                                marker=dict(line=dict(color="darkgray",
                                                      width=0.5)),
                                colorbar=dict(tickvals=[0, 1, 2, 3, 4],
                                              ticktext=['1', '10', '100', '1000', '10000'],
                                              outlinecolor='black',
                                              outlinewidth=0.5,
                                              thickness=20,
                                              len=0.7,
                                              title='# Samples',
                                              titlefont=dict(size=StyleSheet.annotation.font_size,
                                                             family=StyleSheet.annotation.font,
                                                             color=StyleSheet.annotation.color),
                                              titleside="right",)))
    # Layout
    fig.update_layout(autosize=True,
                      dragmode=False,
                      margin={"r": 0, "t": 0, "l": 0, "b": 0},
                      geo=dict(showframe=False,
                               showcoastlines=False,
                               projection_type='equirectangular'),
                      legend={"orientation": "h"})
    return fig


def plot_analysis_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All', normalize=True, ordinary=True):

    if lineage == 'All' and variant == 'All':
        _, voc_meta_df = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date, exclude_lineage=True, exclude_variant=True)
        _, nonvoc_meta_df = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)

    else:
        exclude_lineage = False if lineage == 'All' else True
        exclude_variant = False if variant == 'All' else True
        _, voc_meta_df = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
        _, nonvoc_meta_df = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date, exclude_lineage=exclude_lineage, exclude_variant=exclude_variant)

    # Calculations
    voc_counts = voc_meta_df.groupby('release_date').count().iloc[:, 0]
    nonvoc_counts = nonvoc_meta_df.groupby('release_date').count().iloc[:, 0]
    merge_df = pd.merge(nonvoc_counts, voc_counts, left_index=True, right_index=True, how='outer').fillna(0)

    # Annotation with ML
    if len(nonvoc_counts) and len(voc_counts):
        y = merge_df.iloc[:, 1] / merge_df.sum(axis=1)
        x = sm.add_constant(np.arange(len(y)))
        model = sm.OLS(y, x).fit()
        b1 = model.params[1].round(3)
        p = model.pvalues[1].round(3)
    else:
        b1 = np.nan
        p = np.nan
    annotation = f'Rate of Change Regression Analysis: β1={b1}, p={p}'

    # Labels
    variant_row = variant_df[variant_df.start_position == 23402].iloc[0]
    variant_name = variant_row.reference_bases + str(variant_row.start_position) + variant_row.alternate_bases
    xaxes_title_text = 'Collection Date'
    yaxes_title_text = '# of Samples'
    if lineage == 'All' and variant == 'All':
        names = ['All Samples', 'Other Samples']
    elif lineage == 'All' and variant != 'All':
        names = ['Other Samples', variant_name]
    elif lineage != 'All' and variant == 'All':
        names = ['Other Samples', variant_name]
    elif lineage != 'All' and variant != 'All':
        names = ['Other Samples', lineage + ' + ' + variant_name]

    return plot_bar(merge_df.index,
                    merge_df.values,
                    names,
                    xaxes_title_text,
                    yaxes_title_text,
                    annotation=annotation,
                    color_scale=[StyleSheet.plot.secondary_color, StyleSheet.plot.primary_color],
                    normalize=normalize,
                    ordinary=ordinary)


def plot_location_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All'):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
    x = meta_df_oi.location.value_counts().index
    y = pd.concat([meta_df_oi[~meta_df_oi.lineage.isin(['B.1.1.7', 'B.1.351', 'P.1'])].location.value_counts(),
                   meta_df_oi[meta_df_oi.lineage == 'B.1.1.7'].location.value_counts(),
                   meta_df_oi[meta_df_oi.lineage == 'B.1.351'].location.value_counts(),
                   meta_df_oi[meta_df_oi.lineage == 'P.1'].location.value_counts(),], axis=1).fillna(0).astype(int).values
    names = ['Non-LoC', 'B.1.1.7 (U.K.)', 'B.1.351 (S.A.)', 'P.1 (Brazil)']
    xaxes_title_text = 'Location'
    yaxes_title_text = 'Frequency'
    return plot_bar(x, y, names, xaxes_title_text, yaxes_title_text, color_scale=StyleSheet.plot.color_scale_2[::2])


def plot_lineage_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All', normalize=True, ordinary=True):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
    meta_df_oi = meta_df_oi.sort_values('release_date')
    x = pd.to_datetime(meta_df_oi.release_date.unique())
    y = pd.concat([meta_df_oi[~meta_df_oi.lineage.isin(['B.1.1.7', 'B.1.351', 'P.1'])].release_date.value_counts(),
                   meta_df_oi[meta_df_oi.lineage == 'B.1.1.7'].release_date.value_counts(),
                   meta_df_oi[meta_df_oi.lineage == 'B.1.351'].release_date.value_counts(),
                   meta_df_oi[meta_df_oi.lineage == 'P.1'].release_date.value_counts()], axis=1).fillna(0).astype(int).values
    names = ['Non-LoC', 'B.1.1.7 (U.K.)', 'B.1.351 (S.A.)', 'P.1 (Brazil)']
    xaxes_title_text = 'Collection Date'
    yaxes_title_text = 'Frequency'
    return plot_bar(x, y, names, xaxes_title_text, yaxes_title_text, color_scale=StyleSheet.plot.color_scale_2[::2], normalize=normalize, ordinary=ordinary)


def plot_continent_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All', normalize=True, ordinary=True):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
    meta_df_oi = meta_df_oi.sort_values('release_date')
    x = pd.to_datetime(meta_df_oi.release_date.unique())
    y = meta_df_oi.value_counts(['release_date', 'continent']).unstack().fillna(0)
    names = y.columns.values
    y = y.values
    xaxes_title_text = 'Collection Date'
    yaxes_title_text = '# of Samples'
    loc_counts = meta_df_oi[meta_df_oi.lineage.isin(['B.1.1.7', 'B.1.351', 'P.1'])].release_date.value_counts()
    line_y = pd.concat([loc_counts, x.to_series()], axis=1).fillna(0).release_date.values
    line_yaxes_title_text = '# of VOC Samples'
    return plot_bar(x, y, names, xaxes_title_text, yaxes_title_text, line_y, line_yaxes_title_text, color_scale=StyleSheet.plot.color_scale_2[::2], normalize=normalize, ordinary=ordinary)


def plot_bar(x: pd.DatetimeIndex,
             y: NDArray[(Any, Any), int],
             names: NDArray[(Any), str],
             xaxes_title_text: Optional[str] = None,
             yaxes_title_text: Optional[str] = None,
             line_y: NDArray[(Any), int] = None,
             line_yaxes_title_text: Optional[str] = None,
             annotation: Optional[str] = None,
             color_scale: Optional[list] = None,
             normalize: bool = False,
             ordinary: bool = True):

    if not ordinary:
        line_y = np.cumsum(line_y, axis=0) if line_y is not None else line_y
        y = np.cumsum(y, axis=0)

    if normalize:
        line_y = line_y / y.sum() if line_y is not None else line_y
        y = pd.DataFrame(y).div(y.sum(axis=1), axis=0).values

    # Round to avoid excessive decimals in interactive display
    y = y.round(3)
    line_y = line_y.round(5) if line_y is not None else line_y

    # Figure
    fig = make_subplots(specs=[[{"secondary_y": True}]])

    # Plot 1
    for i, name in zip(range(y.shape[1]), names):
        fig.add_trace(go.Bar(x=x,
                             y=y[:, i],
                             name=name,
                             marker_color=color_scale[i] if color_scale else None),
                      secondary_y=False)

    # Plot 2
    if line_y is not None:
        fig.add_trace(go.Scatter(x=x,
                                 y=line_y,
                                 fillcolor=StyleSheet.plot.red,
                                 marker_color=StyleSheet.plot.red,
                                 name='# of VOC Samples'),
                      secondary_y=True)

    # X-axis 1
    fig.update_xaxes(title_text=xaxes_title_text,
                     titlefont=dict(size=StyleSheet.xaxis_title.font_size,
                                    family=StyleSheet.xaxis_title.font,
                                    color=StyleSheet.xaxis_title.color))

    # Y-axis 1
    yaxes_title_text = f'Cumulative {yaxes_title_text}' if not ordinary else yaxes_title_text
    yaxes_title_text = f'Normalized {yaxes_title_text}' if normalize else yaxes_title_text
    fig.update_yaxes(title_text=yaxes_title_text,
                     titlefont=dict(size=StyleSheet.yaxis_title.font_size,
                                    family=StyleSheet.yaxis_title.font,
                                    color=StyleSheet.yaxis_title.color),
                     showgrid=True,
                     secondary_y=False,
                     gridcolor=StyleSheet.gridline.color)

    # Y-axis 2
    if line_y is not None:
        line_yaxes_title_text = f'Cumulative {line_yaxes_title_text}' if not ordinary else line_yaxes_title_text
        line_yaxes_title_text = f'Normalized {line_yaxes_title_text}' if normalize else line_yaxes_title_text
        fig.update_yaxes(title_text=line_yaxes_title_text,
                         titlefont=dict(size=StyleSheet.yaxis_title.font_size,
                                        family=StyleSheet.yaxis_title.font,
                                        color=StyleSheet.yaxis_title.color),
                         showgrid=False,
                         secondary_y=True,
                         gridcolor=StyleSheet.gridline.color)

    # Add annotation
    if annotation:
        fig.update_layout(annotations=[dict(x=0.45,
                                            y=1.15,
                                            xref='paper',
                                            yref='paper',
                                            text=annotation,
                                            showarrow=False,
                                            font=dict(size=StyleSheet.annotation.font_size,
                                                      family=StyleSheet.annotation.font,
                                                      color=StyleSheet.annotation.color))])

    # Layout
    fig.update_layout(autosize=True,
                      barmode='stack',
                      hovermode='x unified',
                      plot_bgcolor='white')
    return fig


def plot_analysis(df_1, df_2, normalize=True, ordinary=True):

    # Data merge
    merge_df = pd.merge(df_1, df_2, left_index=True, right_index=True, how='outer').fillna(0)

    # ML
    if len(df_1) and len(df_2):
        y = merge_df.iloc[:, 1] / merge_df.sum(axis=1)
        x = sm.add_constant(np.arange(len(y)))
        model = sm.OLS(y, x).fit()
        b1 = model.params[1].round(3)
        p = model.pvalues[1].round(3)
    else:
        b1 = np.nan
        p = np.nan

    # Cumulative
    if not ordinary:
        merge_df = merge_df.cumsum(axis=0)

    # Normalize
    if normalize:
        merge_df = merge_df.div(merge_df.sum(axis=1), axis=0)

    # Figure
    fig = go.Figure()

    # Figure 1a
    fig.add_trace(go.Bar(x=merge_df.iloc[:, 0].index,
                         y=merge_df.iloc[:, 0].values,
                         marker_color=StyleSheet.plot.secondary_color,
                         name='Base Sample',
                         legendgroup='A'))

    # Figure 1b
    fig.add_trace(go.Bar(x=merge_df.iloc[:, 1].index,
                         y=merge_df.iloc[:, 1].values,
                         marker_color=StyleSheet.plot.primary_color,
                         name='Selected Sample',
                         legendgroup='B'))

    # Y-axis
    title_text = f'Cumulative Frequency' if not ordinary else 'Frequency'
    title_text = f'Normalized {title_text}' if normalize else title_text
    fig.update_yaxes(title_text=title_text,
                     titlefont=dict(size=StyleSheet.yaxis_title.font_size,
                                    family=StyleSheet.yaxis_title.font,
                                    color=StyleSheet.yaxis_title.color),
                     showgrid=True,
                     gridcolor=StyleSheet.gridline.color,)

    # X-axis
    fig.update_xaxes(title_text="Collection Date",
                     titlefont=dict(size=StyleSheet.xaxis_title.font_size,
                                    family=StyleSheet.xaxis_title.font,
                                    color=StyleSheet.xaxis_title.color))

    # Layout
    fig.update_layout(autosize=True,
                      barmode='stack',
                      plot_bgcolor='white',
                      annotations=[dict(x=0.55,
                                        y=1.15,
                                        xref='paper',
                                        yref='paper',
                                        text=f'Rate of Change Regression Analysis: β1={b1}, p={p} (α=0.05)',
                                        showarrow=False,
                                        font=dict(size=StyleSheet.annotation.font_size,
                                                  family=StyleSheet.annotation.font,
                                                  color=StyleSheet.annotation.color))])

    return fig


def plot_needle_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All'):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
    pos_freq = variant_df_oi.start_position.value_counts()
    pos_freq = pos_freq.head(100)
    positions = pos_freq.index.values
    frequencies = pos_freq.values
    if not len(positions) or not len(frequencies):
        positions = frequencies = None

    return plot_needle(positions,
                       frequencies,
                       annotation_df[['start', 'end', 'protein']].values,
                       title='Mutation Frequency Across the SARS-CoV-2 Genome')


def plot_needle(
    positions: np.ndarray,
    frequencies: np.ndarray,
    annotations: np.ndarray = None,
    title: str = '',
    xlabel: str = 'Position (BP)',
    ylabel: str = 'Mutation Frequency',
    legend: bool = True,
) -> None:
    """
    Creates manhattan plot using plotly.
    :param chromosomes: 1d int array of chromosome numbers
    :param positions: 1d int array of position numbers
    :param pvalues: 1d float array of pvalues
    :param title: Title of Manhattan plot, defaults to ''
    :param xlabel: X axis label, defaults to 'Position (BP)'
    :param ylabel: Y axis label, defaults to 'Mutation Frequency'
    :param legend: Show legend for domains
    """

    # Nan check
    notnan = True
    if positions is None or frequencies is None:
        notnan = False
        positions = np.array([0, 30000])
        frequencies = np.array([1, 1])

    # Figure
    fig = go.Figure()

    # V-Lines
    if notnan:
        for position, frequency in zip(positions, frequencies):
            fig.add_trace(go.Scatter(x=[position, position],
                                     y=[0, frequency],
                                     mode='lines',
                                     marker=dict(color='black'),
                                     hoverinfo='skip',
                                     showlegend=False))

    if notnan:
        # Plots
        fig.add_trace(go.Scatter(x=positions,
                                 y=frequencies,
                                 hoverinfo='x + y',
                                 showlegend=False,
                                 mode='markers',
                                 marker=dict(
                                     size=8,
                                     color=StyleSheet.plot.red,
                                     line=dict(width=0, color=StyleSheet.plot.black))))

    # Domain tabs
    color_scale_2 = copy.deepcopy(StyleSheet.plot.color_scale_2)
    random.shuffle(color_scale_2)
    for i, annotation in enumerate(annotations):
        fig.add_trace(go.Scatter(x=[annotation[0], annotation[0], annotation[1], annotation[1]],
                                 y=[-frequencies.max() * 0.10, 0, 0, -frequencies.max() * 0.10],
                                 fill='toself',
                                 fillcolor=color_scale_2[::1][i],
                                 mode='none',
                                 name=annotation[2],
                                 hoverinfo='name',))

    # Axes
    fig.update_xaxes(title=xlabel,
                     range=[positions.min(), positions.max()],
                     linecolor=StyleSheet.axes.color,
                     titlefont=dict(size=StyleSheet.xaxis_title.font_size,
                                    family=StyleSheet.xaxis_title.font,
                                    color=StyleSheet.xaxis_title.color))
    fig.update_yaxes(title=ylabel,
                     range=[-frequencies.max() * 0.10, frequencies.max() * 1.10],
                     linecolor=StyleSheet.axes.color,
                     titlefont=dict(size=StyleSheet.yaxis_title.font_size,
                                    family=StyleSheet.yaxis_title.font,
                                    color=StyleSheet.yaxis_title.color))
    # Layout
    fig.update_layout(template='simple_white',
                      showlegend=legend,)

    return fig


def plot_corr_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All'):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)
    variant_df_oi = variant_df_oi[variant_df_oi.start_position.isin(list(B117.keys()) +
                                                                    list(B1351.keys()) +
                                                                    list(P1.keys()))]
    X = pd.crosstab(variant_df_oi.sequence_accession, variant_df_oi.start_position)
    return plot_corr(X)


def plot_corr(X: pd.DataFrame):
    # X should be ct

    # Figure
    if len(X):
        fig = ff.create_dendrogram(X.iloc[:20, :20],
                                   labels=X.columns[:20],
                                   orientation='right',
                                   distfun=lambda x: pdist(x.T, metric='hamming'),
                                   linkagefun=hierarchy.ward)
    else:
        fig = go.Figure()

    # Axes
    fig.update_xaxes(title='Normalized Distance',
                     linecolor=StyleSheet.axes.color,
                     ticks='outside', mirror=True, showline=True,
                     titlefont=dict(size=StyleSheet.xaxis_title.font_size,
                                    family=StyleSheet.xaxis_title.font,
                                    color=StyleSheet.xaxis_title.color))

    fig.update_yaxes(title='Position',
                     linecolor=StyleSheet.axes.color,
                     ticks='outside', mirror=True, showline=True,
                     tickfont=dict(color=StyleSheet.yaxis_title.color),
                     titlefont=dict(size=StyleSheet.yaxis_title.font_size,
                                    family=StyleSheet.yaxis_title.font,
                                    color=StyleSheet.yaxis_title.color))
    # Layout
    fig.update_layout(autosize=True,
                      template='simple_white')
    # Hoverinfo
    fig.update_traces(hoverinfo='x + y')
    return fig


def plot_voc_table_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All'):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)

    # Merging variant and meta df
    vocs = {}
    for d in [B117, B1351, P1]:
        vocs.update(d)
    merge_df = pd.merge(variant_df_oi, meta_df_oi, left_on='sequence_accession', right_on='accession')
    merge_df_oi = merge_df[merge_df.start_position.isin(list(vocs.keys()))]

    # Total counts and per year counts
    counts_total = merge_df_oi.start_position.value_counts()
    counts_2020 = merge_df_oi[(merge_df_oi.release_date >= datetime(2020, 1, 1)) & (merge_df_oi.release_date < datetime(2021, 1, 1))].start_position.value_counts()
    counts_2021 = merge_df_oi[(merge_df_oi.release_date >= datetime(2021, 1, 1)) & (merge_df_oi.release_date < datetime(2022, 1, 1))].start_position.value_counts()

    # Finding ROI
    diff_1 = merge_df_oi[(merge_df_oi.release_date + pd.offsets.MonthBegin(-1)) == pd.to_datetime(date.today() + pd.offsets.MonthBegin(-1))]
    diff_2 = merge_df_oi[(merge_df_oi.release_date + pd.offsets.MonthBegin(-1)) == pd.to_datetime(date.today() + pd.offsets.MonthBegin(-3))]
    total_diff = pd.DataFrame(diff_1.start_position.value_counts().subtract(diff_2.start_position.value_counts(), fill_value=0), index=counts_total.index).fillna(0)
    total_add = pd.DataFrame(diff_2.start_position.value_counts().add(diff_1.start_position.value_counts(), fill_value=0), index=counts_total.index).fillna(0)
    total_roc = (total_diff / total_add).fillna(0) * 100

    # Genomic position
    genomic_positions = counts_total.index.to_series()

    # Protein annotation
    gene_labels = genomic_positions.apply(lambda x: annotate(
        x,
        annotation_df.start.values,
        annotation_df.end.values,
        annotation_df.protein.values,
        'Intergenic Region'))

    # Dataframe creation
    final_df = pd.concat([gene_labels, genomic_positions, counts_total, counts_2020, counts_2021, total_roc], axis=1).fillna(0).reset_index()
    final_df = pd.DataFrame(final_df.values, index=final_df.index, columns=['Genomic Position', 'Gene', 'VOC', 'Total VOCs', 'Total VOCs (2020)', 'Total VOCs (2021)', '% Change (Last Month)'])

    # Formatting
    final_df.VOC = list(map(vocs.get, final_df.VOC))
    final_df['% Change (Last Month)'] = final_df['% Change (Last Month)'].astype(str) + '%'

    fig = go.Figure(data=[go.Table(
        header = dict(values = list(final_df.columns), align = "left" ),
        cells = dict(values = [final_df['Genomic Position'], final_df['Gene'], final_df['VOC'], final_df['Total VOCs'], final_df['Total VOCs (2020)'], final_df['Total VOCs (2021)'], final_df['% Change (Last Month)']], align="left")
    )])

    fig.update_layout(autosize=True,
                      template='simple_white')

    return fig


def plot_lineage_table_search(variant_df, meta_df, annotation_df, lineage='All', variant='All', location='All', start_date='All', end_date='All'):
    variant_df_oi, meta_df_oi = format_search_data(variant_df, meta_df, lineage, variant, location, start_date, end_date)

    # Select top 10 lineages, force include the lineages of concern
    meta_df_oi = meta_df_oi[meta_df_oi.lineage.isin(np.unique(np.r_[meta_df_oi.lineage.value_counts().head(50).index.values, ['B.1.1.7', 'B.1.351', 'P.1']]))]

    # Total counts and per year counts
    counts_total = meta_df_oi.lineage.value_counts()
    counts_2020 = meta_df_oi[(meta_df_oi.release_date >= datetime(2020, 1, 1)) & (meta_df_oi.release_date < datetime(2021, 1, 1))].lineage.value_counts()
    counts_2021 = meta_df_oi[(meta_df_oi.release_date >= datetime(2021, 1, 1)) & (meta_df_oi.release_date < datetime(2022, 1, 1))].lineage.value_counts()

    # Finding ROC
    diff_1 = meta_df_oi[(meta_df_oi.release_date + pd.offsets.MonthBegin(-1)) == pd.to_datetime(date.today() + pd.offsets.MonthBegin(-1))]
    diff_2 = meta_df_oi[(meta_df_oi.release_date + pd.offsets.MonthBegin(-1)) == pd.to_datetime(date.today() + pd.offsets.MonthBegin(-2))]
    total_diff = pd.DataFrame(diff_1.lineage.value_counts().subtract(diff_2.lineage.value_counts(), fill_value=0), index=counts_total.index).fillna(0)
    total_add = pd.DataFrame(diff_2.lineage.value_counts().add(diff_1.lineage.value_counts(), fill_value=0), index=counts_total.index).fillna(0)
    total_roc = (total_diff / total_add).fillna(0) * 100

    # Proportion Lineage
    lineage_proportion = (counts_total / len(meta_df_oi)) * 100

    # Declaring DF
    final_df = pd.concat([counts_total, lineage_proportion, counts_2020, counts_2021, total_roc], axis=1).fillna(0).astype(int).reset_index()
    final_df = pd.DataFrame(final_df.values, index=final_df.index, columns=['Lineage', 'Total Lineages', '% of All Samples', 'Total Lineages (2020)', 'Total Lineages (2021)', '% Change (Last Month)'])

    # Formatting
    final_df['% Change (Last Month)'] = final_df['% Change (Last Month)'].astype(str) + '%'
    final_df['% of All Samples'] = final_df['% of All Samples'].astype(str) + '%'

    fig = go.Figure(data=[go.Table(
        header = dict(values = list(final_df.columns), align = "left" ),
        cells = dict(values = [final_df['Lineage'], final_df['Total Lineages'], final_df['% of All Samples'], final_df['Total Lineages (2020)'], final_df['Total Lineages (2021)'], final_df['% Change (Last Month)']], align="left")
    )])

    fig.update_layout(autosize=True,
                      template='simple_white')

    return fig
