import os
import argparse
import csv
import math
import pandas as pd
import numpy as np
import colorsys
from collections import Counter
from collections import defaultdict
from typing import List, Dict
from itertools import combinations
from sklearn.cluster import DBSCAN
from sklearn.neighbors import NearestNeighbors
import plotly.graph_objects as go
import plotly.io as pio
import dash
from dash import dcc, html, Input, Output, State, dash_table
from dash.exceptions import PreventUpdate

def parse_log(run_name, path):
    """This function parses an ECTB-based run into a run dictionary containing the used flags, their values, and the status.

    Args:
        run_name (string): The name of the run in the regression context.
        path (string): The full path to the regression directory.

    Returns:
        dict: Run dictionary, associating {flag_name:flag_value}.
    """
    # Store flag names and their associated values
    run_dict = dict()
    run_dict["run_name"] = run_name
    # Read lines of current file
    with open(path, 'r') as file:
        lines = file.readlines()
    # Start with first line, go to the plusarg that sets the sequence name
    # Project prerequisite -> only one top-level sequence
    # Input file lines iterator
    line_index = 0
    while(line_index < len(lines) and lines[line_index].strip().find("+seq0_name=") == -1):
        line_index += 1; # Skip over lines that don't contain the sequence name

    # If ECTB top sequence name plusarg is not found, then this run is not ECTB based
    # Skip over this file 
    if line_index >= len(lines):
        return False
    # Get sequence name
    seq_name_start_idx = lines[line_index].strip().find("=") + 1; # Starting point of the sequence name
    seq_name = lines[line_index].strip()[seq_name_start_idx:]
    # Go to UVM_INFO ECTB dump
    # This should look like this example:
    # UVM_INFO /home/andbli/git/amiq_pclust/amiq23_md/tb/lib/sv/amiq_ectb_lib/amiq_ectb_reg_functions.svh(36) @ 0: reporter@@secv1 [secv1] +secv1_nof_resets=small
    while(line_index < len(lines) and lines[line_index].strip().find("amiq_ectb_reg_functions.svh") == -1):
        line_index += 1; # Skip over lines that are not a UVM_INFO ECTB dump

    # The ECTB flag dump was not found, so this run is not transparent enough to be analyzed
    # Skip over this file
    if line_index >= len(lines):
        return False

    # Parse features and values from ECTB uvm_infos
    while("amiq_ectb_reg_functions.svh" in lines[line_index].strip()):
        ectb_line = lines[line_index].strip()
        # If the uvm_info is a flag dump
        if(("+" + seq_name) in ectb_line):
            # Skip sequence name and underscore
            # +seq_name_flag_name = flag_value
            flag_name_start_idx = ectb_line.find("+" + seq_name) + len(seq_name) + 2; # Starting point of flag name, adding 2 goes right after the underscore
            flag_name_end_idx = ectb_line.find("="); # End point of flag name
            flag_name = ectb_line[flag_name_start_idx:flag_name_end_idx]
            flag_value_start_idx = flag_name_end_idx + 1
            flag_value = ectb_line[flag_value_start_idx:]
            run_dict[flag_name] = flag_value

        line_index += 1; # Iterate through ECTB dump
        # This is an ECTB run, but it has not finished
        if line_index >= len(lines):
            return False

    # Find error message, if it exists
    # This should look like this example:
    # xmsim: *E,ASRTST (/home/andbli/git/amiq_pclust/amiq23_md/tb/lib/sv/amiq_matrix_agent/amiq_matrix_if.sv,106): (time 119430 NS)
    # Assertion amiq_md_tb_top.input_if.AMIQ_MD_ERROR3 has failed
    # endl 
    # ERROR3 <- error message 

    while (line_index < len(lines) and lines[line_index].strip().find("ASRTST") == -1):
        line_index += 1; # Skip over lines that are not an assertion message failure

    # This run has not failed    
    if line_index >= len(lines):
        run_dict["status"] = "passed"

    # This run has failed with a certain label, which is a feature in itself
    else:
        error_line = lines[line_index].strip()
        error_name_start_idx = error_line.rfind(".") + 1; # The last occurrence of a dot is followed by the assertion tag
        error_name_end_idx = error_line.rfind(" has failed")
        error_name = error_line[error_name_start_idx:error_name_end_idx]
        run_dict["status"] = error_name
    
    return run_dict

# Transform all run dictionaries into the desired table
# Perform set reunion on run features, except run_name and status, which will be added manually
def get_header(runs):
    """This function gets all the different types of flags used in the regression, and orders them based on how often they are used.

    Args:
        runs (list of dict): List of all dictionaries produced by parse_log.

    Returns:
        list: The matrix header.
    """
    regression_features = list(set().union(*[run.keys() - {'run_name','status'} for run in runs]))

    # Order features in the matrix in regard to the hits
    # Prepare the empty grid of the matrix to be populated
    feature_frequency = Counter(); # Specialized container in collections, used to store the nof_occurrences of an element like a dictionary
    for run in runs:
        for feature in regression_features:
            if feature in run:
                feature_frequency[feature] += 1

    # Sort column based on the features with most hits first
    # In case of ties, sort alphabetically
    regression_features = sorted(regression_features, key=lambda x: (-feature_frequency[x], x))
    regression_features = ['run_name', 'status'] + regression_features

    return regression_features

def dice_distance_matrix(failed_matrix):
    """Compute Dice distance between runs.
    Args:
        failed_matrix (DataFrame): Pandas DataFrame showing the parseg regression.

    Returns:
        DataFrame: Dice distances matrix.
    """
    dummy = failed_matrix.copy()
    dummy.reset_index(drop=True, inplace=True)
    N = len(dummy)
    dice_matrix = np.zeros((N, N))
    for i in range(N - 1):
        for j in range(i + 1, N):
            a = set(k for k in dummy.loc[i].tolist() if k != "nan")
            b = set(k for k in dummy.loc[j].tolist() if k != "nan")
            #Dice Formula
            distance = 1 - 2 * len(a.intersection(b)) / (len(a) + len(b))
            dice_matrix[i, j] = dice_matrix[j, i] = distance
    dice_matrix = pd.DataFrame(dice_matrix)
    # dice_matrix.to_csv("dice_matrix.csv", index = True, header = True)
    return dice_matrix

def cluster(eps, min_samples, algorithm, distance_matrix):
    """Cluster given points, regarding certain algorithm and hyperparameters

    Args:
        eps (float): Radius, spanning from 0 to 1.
        min_samples (int): Min number of points in a cluster, has to be greater than 2.
        algorithm (string): Name of the used clustering algorithm.
        distance_matrix (DataFrame): Dataset to be clustered.

    Returns:
        list: cluster labels for each point in dataset.
    """
    # global_weights = compute_weights(runs_matrix)
    
    if algorithm == "DBSCAN":
        dbscan = DBSCAN(eps=eps, min_samples=min_samples, metric="precomputed")
        clusters = dbscan.fit_predict(distance_matrix)

    elif algorithm == "OPTICS":
        if min_samples >= 2:
            optics = OPTICS(min_samples=min_samples, metric="precomputed")
            clusters = optics.fit_predict(distance_matrix)
        else:
            clusters = list(range(len(distance_matrix)))

    elif algorithm == "HDBSCAN":
        if min_samples >= 2:
            hdbscan = HDBSCAN(min_samples=min_samples, metric="precomputed")
            clusters = hdbscan.fit_predict(distance_matrix)
        else:
            clusters = list(range(len(distance_matrix)))

    return clusters

def get_optimum_eps(distance_matrix, k=None):
    """Get the optimum eps value for this dataset, given as a distance matrix.
    Args:
        distance_matrix (DataFrame): Similarity measure between all runs, given as a symmetric matrix.

    Returns:
        float, graph: Optimum eps and knn graph.
    """
    distances = []
    # For each point, compute distances to its k-nearest neighbors
    for _, row in distance_matrix.iterrows():
        row = np.array(row)
        row = np.sort(row)
        kth_nn = row[k-1]
        distances.append(kth_nn)

    distances = np.array(distances)
    distances = np.sort(distances)

    def calculate_curvature(x, y):
        """Calculate curvature of point, given x and y coordinates.

        Args:
            x (list): X coordinates in KNN graph.
            y (list): Y coordinates in KNN graph.

        Returns:
            list: Curvatures of the dataset.
        """
        # Compute the first derivatives (x' and y')
        dx = np.gradient(x)
        dy = np.gradient(y)

        # Compute the second derivatives (x'' and y'')
        ddx = np.gradient(dx)
        ddy = np.gradient(dy)

        # Finally, compute the curvature for each point
        curvature = np.abs(dx * ddy - dy * ddx) / np.power(dx**2 + dy**2, 1.5)
        return curvature

    def find_first_plateau(values):
        """Find the first plateau in the KNN graph, meaning a suitable eps value.

        Args:
            values (list): Curvature values of dataset.

        Returns:
            int: Index of the first plateau in KNN graph.
        """
        # Create an array of indices to represent the x values
        x = np.arange(len(values))
        y = np.array(values)

        # Calculate curvature
        curvature = list(calculate_curvature(x, y))
        # Find the index of the maximum curvature   
        plateau_index = curvature.index(0)

        return plateau_index
    
    # Optimum eps is the first plateau in the sorted graph
    elbow_index = find_first_plateau(distances)

    # Plot the distances
    fig = go.Figure(go.Scatter(
        y=[round(distance, 4) for distance in distances],
        mode='lines+markers',
    ))
    fig.update_layout(
        title=f"Sorted {k}nn distance graph for eps optimization",
        xaxis_title="Points",
        yaxis_title="KNN distance"
    )
    return distances[elbow_index], fig

def evaluate_noise(failed_matrix):
    """Compute noise score for labeled dataset.

    Args:
        failed_matrix (DataFrame): Labeled (clustered) dataset.

    Returns:
        float: Noise points fraction, spanning from 0 to 1.
    """
    # Evaluate noise
    nof_noise = failed_matrix[failed_matrix["cluster"] == -1].shape[0]
    noise_score = nof_noise / len(failed_matrix)
    
    return noise_score

def generate_pastel_colors(num_colors):
    """Generate evenly spaced pastel colors.

    Args:
        num_colors (int): Number of colors to be generated

    Returns:
        list: List of hex codes of pastel colors.
    """
    pastel_colors = []
    hue = 0
    saturation = 0.5
    value = 0.8
    
    # Generate evenly spaced hues
    if num_colors != 0:
        hue_delta = 360.0 / num_colors
    
    # Generate pastel colors
    for _ in range(num_colors):
        # Convert HSV to RGB
        r, g, b = colorsys.hsv_to_rgb(hue / 360.0, saturation, value)
        
        # Convert RGB to hex
        hex_color = "#{:02X}{:02X}{:02X}".format(int(r * 255), int(g * 255), int(b * 255))
        
        # Append hex color to list
        pastel_colors.append(hex_color)
        
        # Increment hue
        hue += hue_delta
    
    return pastel_colors

def generate_dict_colors(failed_matrix):
    """Generate colors for the resulted number of clusters.

    Args:
        failed_matrix (DataFrame): Labeled (clustered) dataset.

    Returns:
        dict, list: color dictionary {cluster_label:assigned_color}, list of unique clusters in dataset.
    """
    unique_clusters = sorted(list(set(failed_matrix["cluster"])))
    dict_colors = {-1:'#000000'}

    if -1 in unique_clusters:
        unique_clusters.remove(-1)
    pastel = generate_pastel_colors(len(unique_clusters))

    for i in range(len(unique_clusters)):
        dict_colors[i] = pastel[i]
    return dict_colors, unique_clusters

def compute_weights(matrix):
    """
    Computes the frequency of combinations of flags, out of the runs matrix.
    Args:
        matrix (DataFrame): Matrix showing used parameters in run and it's status.

    Returns:
        Dictionary of combinations and their frequency.
    """
    weights = dict()
    for i in matrix.index.tolist():
        run = matrix.loc[i].tolist()
        run = list(flag for flag in run[1:] if flag != "nan")
        subsets = subsets_generator(run, 2, len(run))
        for subset in subsets:
            if matrix.loc[i,"status"] != "passed":
                if subset in weights:
                    weights[subset] += 1
                else:
                    weights[subset] = 1
            else:
                if subset in weights:
                    weights[subset] -= 1
                else:
                    weights[subset] = -1
    return weights

def subsets_generator(used_flags, nof_min_elements, nof_max_elements):
    """Generate all subsets of a sequence with nof_elements in range(nof_min_elements, nof_max_elements + 1).
    Args:
        used_flags (list): List of all flags used in the sequence.
        nof_min_elements (int): Minimum number of elements in a subset.
        nof_max_elements (int): Maximum number of elements in a subset.

    Returns:
        List of all subsets.
    """
    subsets = []
    for r in range(nof_min_elements, nof_max_elements + 1):
        for subset in combinations(used_flags, r):
            subsets.append(subset)
    return subsets

# GUI
def plot_sankey(
    failed_matrix, failed_matrix_copy, distance_matrix,
    dict_colors, unique_clusters, regression_features, feature_frequency,
    eps_opt, min_samples_opt, noise, knn_graph
    ):
    """Launch interactive Dash app.

    Args:
        failed_matrix (DataFrame): Labeled (clustered) dataset.
        failed_matrix_copy (DataFrame): Copy of labeled (clustered) dataset.
        distance_matrix (DataFrame): Similarity measure between all runs, given as a symmetric matrix.
        dict_colors (dict): Color dictionary {cluster_label:assigned_color}.
        unique_clusters (list): List of unique clusters in dataset.
        regression_features (list): List of types of flags used in regression.
        feature_frequency (dict): Number of occurrences of flag in regression.
        eps_opt (float): First plateau of the KNN graph.
        min_samples_opt (int): ln(nof_points_in_dataset)
        noise (float): Noise score of clustered dataset.
        knn_graph (graph): KNN graph for each point in the dataset, K = 0.25 * nof_points_in_dataset.

    """

    color_options = {
                    "white": "#FFFFFF",
                    "red": "#FF0000",
                    "green": "#00FF00",
                    "blue": "#0000FF",
                    "yellow": "#FFFF00",
                    "cyan": "#00FFFF",
                    "magenta": "#FF00FF",
                    "orange": "#FFA500",
                    "purple": "#800080",
                    "brown": "#A52A2A",
                    "pink": "#FFC0CB",
                    "teal": "#008080",
                    "lime": "#00FF00",
                    "olive": "#808000",
                    "navy": "#000080",
                    "maroon": "#800000",
                    "gray": "#808080",
                    "silver": "#C0C0C0",
                    "gold": "#FFD700"
                }

    def generate_sankey_figure(regression_features, failed_matrix):
        header = regression_features + ["status"]
        labels = []
        mapping = {}
        x_values = []
        y_values = []

        step_x = 0.9 / ( len(header) + 1)

        mapped_x = 0.1
        mapped_value = 0

        for cat in header:
            if cat == "run_name":
                extension = failed_matrix.index.tolist()
            else:
                extension = sorted(set(label for label in failed_matrix[cat] if label != "nan"))
            step_y = 1 / (len(extension) + 1);
            labels.extend(extension)
            mapped_y = step_y
            for label in extension:
                mapping[(label, cat)] = mapped_value
                mapped_value += 1
                y_values.append(mapped_y)
                mapped_y += step_y
                x_values.append(mapped_x)
            mapped_x += step_x
        
        colors = []                
        # Process each row in the DataFrame to count frequencies
        sources = []
        targets = []
        for _, row in failed_matrix.iterrows():
            nodes = []
            for cat in header:
                if cat == "run_name":
                    nodes.append((row.name, "run_name"))
                elif row[cat] != "nan":
                    nodes.append((row[cat], cat))

            for i in range(len(nodes)):
                for label, cat in mapping:
                    if nodes[i] == (label, cat):
                        nodes[i] = mapping[(label,cat)]
                        
            for i in range(len(nodes) - 1):
                sources.append(nodes[i])
                targets.append(nodes[i+1])
                colors.append(dict_colors[row["cluster"]])

        # Create lists to store source, target, and value for flows
        values = [1] * len(sources)

        # Create the Sankey diagram
        fig = go.Figure(data = [go.Sankey(
            arrangement="perpendicular",
            node=dict(
                pad=30,
                thickness=10,
                line=dict(color="black", width=0.5),
                label=labels,
                x=x_values,
                y=y_values,
                color="black"
            ),
            link=dict(
                source=sources,
                target=targets,
                value=values,
                color=colors
            ),
            domain=dict(
                x=[0,1],
                y=[0,1]
            ),
        )])
        to_remove = []
        for cat in header:
            if cat != "run_name" and list(set(failed_matrix[cat])) == ["nan"]:
                to_remove.append(cat)
        for cat in to_remove:
            header.remove(cat)
        # Add column labels using annotations
        for i, label in enumerate(header):
            fig.add_annotation(
                x=sorted(list(set(x_values)))[i],  
                y=1,  
                text=label,
                showarrow=False,
                font=dict(
                    size=14,
                    color="black"
                )
            )

        if len(failed_matrix) > 30:
            h = 2000
        else:
            h = 500

        # Update the layout
        fig.update_layout(
            title_text="Sankey Diagram",
            height = h
        )
        
        return fig

    def generate_table_figure(dict_colors, unique_clusters, failed_matrix_copy):
        header_colors = list(dict_colors.values())[1:]
        cell_colors = [f"rgba{tuple(int(header_color[i:i+2], 16) for i in (1, 3, 5)) + (0.5,)}" for header_color in header_colors]

        # Table data to plot
        table_headers = [f"bug_{i}" for i in range(len(unique_clusters))]
        table_cells = []
        
        for cluster in unique_clusters:
            clustered_runs = failed_matrix_copy[failed_matrix_copy["cluster"] == cluster].copy()
            clustered_runs.drop(columns="cluster", inplace = True)
            local_weights = compute_weights(clustered_runs)
            top_value = sorted(local_weights.items(), key=lambda x: (x[1], len(x[0])))[-1]
            cell = [f"Trace: {top_value[0]} ; Count: {top_value[1]}"]
            table_cells.append(cell)
            
        # Table part
        fig = go.Figure(data = [go.Table(
            header=dict(
                values=table_headers,
                fill_color=header_colors,
                font=dict(color='black', size=12),  # Optional: Change the font color and size
                align='center'
            ),
            cells=dict(
                values=table_cells,
                fill_color=cell_colors
            )
        )])
        return fig

    app = dash.Dash(__name__)

    app.layout = html.Div([
        html.H1('Regression Analysis Tool', style={'textAlign': 'center'}),
        html.Br(),

        # Graph Section
        dcc.Graph(id='knn-graph', figure=knn_graph),
        html.Br(),

        # Parameter Update Section
        html.Div([
            html.H2('Parameter Update', style={'textAlign': 'center', 'marginBottom': '20px'}),
            html.Div(
                id='eps-slider',
                children=[
                    dcc.Slider(
                        id='eps-input', min=0.001, max=1.0, step=0.0001,
                        value=round(eps_opt, 4),
                        marks={i / 10: str(i / 10) for i in range(1, 11)},
                        tooltip={"placement": "bottom", "always_visible": False}
                    ),
                    html.Div(id="eps-output", children=f"Selected eps: {round(eps_opt, 4)}", style={'textAlign': 'center', 'marginTop': '10px'})
                ],
                style={'marginBottom': '20px'}
            ),
            html.Div([
                html.Div([
                    dcc.Input(id='pts-input', type="number", min=1, max=50, step=1, value=min_samples_opt, style={'width': '80px', 'marginRight': '20px'}),
                    html.Div(id="pts-output", children=f"Selected minPts: {min_samples_opt}", style={'marginTop': '10px'})
                ], style={'display': 'flex', 'alignItems': 'center', 'justifyContent': 'center'}),
            ], style={'marginBottom': '20px'}),
            html.Div([
                dcc.Dropdown(
                    id='alg-input',
                    options=[{'label': alg, 'value': alg} for alg in ["DBSCAN", "HDBSCAN", "OPTICS"]],
                    value="DBSCAN",
                    style={'width': '50%'}
                ),
                html.Button(id='alg-button', n_clicks=0, children='Change algorithm'),
            ], style={'display': 'flex', 'justifyContent': 'center', 'alignItems':'center', 'marginBottom': '20px'}),
            html.Div(id="noise-output", children=f"Noise: {round(noise, 2)}", style={'textAlign': 'center', 'marginBottom': '20px'}),
        ], style={'border': '1px solid #ccc', 'padding': '20px', 'borderRadius': '5px', 'marginBottom': '40px'}),

        # Filtering Section
        html.Div([
            html.H2('Filtering Options', style={'textAlign': 'center', 'marginBottom': '20px'}),
            html.Div([
                dcc.Input(id='order-input', type='text', placeholder='Enter column order', style={'width': '70%', 'marginRight': '10px'}),
                html.Button(id='reorder-button', n_clicks=0, children='Reorder'),
            ], style={'display': 'flex', 'justifyContent': 'center', 'marginBottom': '20px'}),
            html.Div([
                dcc.Input(id='single-out-input', type='text', placeholder='Enter run name', style={'width': '70%', 'marginRight': '10px'}),
                html.Button(id='single-out-button', n_clicks=0, children='Single out'),
            ], style={'display': 'flex', 'justifyContent': 'center', 'marginBottom': '20px'}),
            html.Div([
                dcc.Input(id='filter-cluster-input', type='text', placeholder='Enter cluster number', style={'width': '40%', 'marginRight': '10px'}),
                html.Button(id='filter-cluster-button', n_clicks=0, children='Filter'),
            ], style={'display': 'flex', 'justifyContent': 'center', 'marginBottom': '20px'}),
            html.Div([
                dcc.Input(id='val-input', type='text', placeholder='Enter value label', style={'width': '40%', 'marginRight': '10px'}),
                html.Button(id='val-button', n_clicks=0, children='Focus'),
            ], style={'display': 'flex', 'justifyContent': 'center', 'marginBottom': '20px'}),
        ], style={'border': '1px solid #ccc', 'padding': '20px', 'borderRadius': '5px', 'marginBottom': '40px'}),

        # Color Update Section
        html.Div([
            html.H2('Color Update', style={'textAlign': 'center', 'marginBottom': '20px'}),
            html.Div([
                dcc.Dropdown(id='bug-input', options=[{'label': f"bug_{i}", 'value': i} for i in unique_clusters], value=unique_clusters[0], style={'width': '40%', 'marginRight': '10px'}),
                dcc.Dropdown(id='color-dropdown', options=[{'label': color, 'value': color_options[color]} for color in color_options], value=color_options["red"], style={'width': '40%', 'marginRight': '10px'}),
                html.Button(id='update-color-button', n_clicks=0, children='Update Color')
            ], style={'display': 'flex', 'justifyContent': 'center', 'marginBottom': '20px'}),
        ], style={'border': '1px solid #ccc', 'padding': '20px', 'borderRadius': '5px', 'marginBottom': '40px'}),

        # Graphs Section
        html.Div([
            dcc.Graph(id='sankey-diagram', figure=generate_sankey_figure(regression_features, failed_matrix)),
            dcc.Graph(id='table-structure', figure=generate_table_figure(dict_colors, unique_clusters, failed_matrix_copy))
        ])
    ])

    
    # Callback to update the Sankey diagram and the table structure
    @app.callback(
        [Output('sankey-diagram', 'figure'),
         Output('table-structure', 'figure'),
         Output('eps-output', 'children'),
         Output('pts-output', 'children'),
         Output('noise-output', 'children'),
         Output('bug-input', 'options'),
         Output('bug-input', 'value'),
         Output('eps-slider', 'style')
        ],

        [Input('update-color-button', 'n_clicks'),
         Input('eps-input', 'value'),
         Input('pts-input', 'value'),
         Input('reorder-button','n_clicks'),
         Input('single-out-button','n_clicks'),
         Input('filter-cluster-button','n_clicks'),
         Input('val-button','n_clicks'),
         Input('alg-button','n_clicks')
        ],

        [State('bug-input', 'value'),
         State('color-dropdown', 'value'),
         State('order-input', 'value'),
         State('single-out-input', 'value'),
         State('filter-cluster-input', 'value'),
         State('val-input', 'value'),
         State('alg-input', 'value')
        ],
         
        prevent_initial_call=True
    )

    def update_diagrams(
        color_clicks, eps_value, pts_value,
        reorder_clicks, run_clicks, filter_clicks, val_clicks, algorithm_clicks,
        bug, color, order, run_name, filter_name, val_name, algorithm):

        nonlocal failed_matrix
        nonlocal failed_matrix_copy
        nonlocal dict_colors
        nonlocal unique_clusters
        nonlocal regression_features
        nonlocal noise
        
        # Determine the trigger of the callback
        ctx = dash.callback_context
        trigger_id = ctx.triggered[0]['prop_id'].split('.')[0]
        runs = []
        filters = []
        if algorithm != "DBSCAN":
            eps_style = {'display':'none'}
        else:
            eps_style = None
        # If the callback was triggered by the eps-input slider
        if trigger_id == 'eps-input' or trigger_id =='pts-input' or (trigger_id == 'alg-button' and algorithm_clicks > 0):
            # Re-calculate clusters
            new_clusters = cluster(eps_value, pts_value, algorithm, distance_matrix)
            k = 0
            for i in failed_matrix_copy.index.tolist():
                failed_matrix.loc[i, "cluster"] = new_clusters[k]
                k += 1
            failed_matrix_copy["cluster"] = new_clusters
            failed_matrix = failed_matrix.sort_values(by="cluster")
            dict_colors, unique_clusters = generate_dict_colors(failed_matrix)
        
        elif trigger_id == 'reorder-button' and reorder_clicks > 0:
            if order is not None and len(order) and order != ['']:
                order = order.split(', ')
                unique_order = []
                for item in order:
                    if item not in unique_order:
                        unique_order.append(item)
                regression_features = unique_order
            else:
                regression_features = sorted(failed_matrix.columns[1:-1].tolist(), key=lambda x: (-feature_frequency[x], x))
                regression_features = ["run_name"] + regression_features
        
        elif trigger_id == 'single-out-button' and run_clicks > 0:
            if run_name is not None and len(run_name) and run_name != ['']:
                runs = run_name.split(', ')
                unique_runs = []
                for item in runs:
                    if item not in unique_runs:
                        unique_runs.append(item)
                runs = unique_runs

        elif trigger_id == 'filter-cluster-button' and filter_clicks > 0:
            if filter_name is not None and len(filter_name) and filter_name != ['']:
                filters = filter_name.split(', ')
                for f in range(len(filters)):
                    filters[f] = int(filters[f].split('_')[1])

        elif trigger_id == 'val-button' and val_clicks > 0:
            if val_name is not None and len(val_name) and val_name != ['']:
                cat = val_name.split('$')[0]
                val = val_name.split('$')[1]

        # If the callback was triggered by the color-dropdown
        elif trigger_id == 'update-color-button' and color_clicks > 0:
            if bug is not None and color is not None:
                # Update the color for the specified bug
                dict_colors[bug] = color
            else:
                dict_colors,_ = generate_dict_colors(failed_matrix)

        # Generate the updated sankey diagram
        # Prioritize bug filters
        if filters is not None and len(filters) and filters != []:
            # If bugs are in the predicted bugs list
            if set(filters) & set(unique_clusters) == set(filters):
                sankey_fig = generate_sankey_figure(regression_features, failed_matrix[failed_matrix["cluster"].isin(filters)])
            else:
                sankey_fig = generate_sankey_figure(regression_features, failed_matrix)
        # Run filters
        elif runs is not None and len(runs) and runs != ['']:
            # If all runs are in the matrix
            if set(runs) & set(failed_matrix.index.tolist()) == set(runs):
                sankey_fig = generate_sankey_figure(regression_features, failed_matrix.loc[runs])
            else:
                sankey_fig = generate_sankey_figure(regression_features, failed_matrix)
        # Focus filters
        elif val_name is not None and len(val_name) and val_name != ['']:
            if cat in regression_features and val in list(set(failed_matrix[cat])):
                sankey_fig = generate_sankey_figure(regression_features, failed_matrix[failed_matrix[cat] == val])
            else:
                sankey_fig = generate_sankey_figure(regression_features, failed_matrix)
        else:
            sankey_fig = generate_sankey_figure(regression_features, failed_matrix)

        # Generate the table figure with the updated colors
        table_fig = generate_table_figure(dict_colors, unique_clusters, failed_matrix_copy)

        return [
            sankey_fig,
            table_fig,
            f"Selected eps:{round(eps_value, 4)}",
            f"Selected minPts:{pts_value}",
            f"Noise:{round(noise, 2)}",
            [{'label': f"bug_{i}", 'value': i} for i in unique_clusters],
            unique_clusters[0] if len(unique_clusters) else None,
            eps_style
            ]

    # Run the Dash app
    app.run_server(debug=True)

# Cluster and visualize regression in dash
def cluster_and_visualize(string_matrix, header):
    """Apply a clustering algorithm on the parsed data and visualize the regression.

    Args:
        string_matrix (DataFrame): Regression matrix.

    """
    string_matrix_copy = string_matrix.copy()
    # Prepare failed matrix for similarity measure
    for i in string_matrix_copy.index.tolist():
        for col in string_matrix_copy.columns.tolist():
            if col != "status" and string_matrix_copy.loc[i, col] != "nan":
                string_matrix_copy.loc[i, col] = col  + "_" + string_matrix_copy.loc[i, col]

    # Default clustering
    # Compute similarity measure
    distance_matrix = dice_distance_matrix(string_matrix_copy)
    nof_dimensions = len(string_matrix_copy.columns) - 2

    # Optimize hyperparameters
    min_samples_opt = math.ceil(np.log(len(string_matrix))) # Heuristic default approach
    eps_opt, knn_graph = get_optimum_eps(distance_matrix=distance_matrix, k=int(0.25*len(string_matrix))) # Heuristic k

    # Cluster and evaluate clustering
    clusters = cluster(eps_opt, min_samples_opt, "DBSCAN", distance_matrix)
    string_matrix["cluster"] = clusters
    string_matrix_copy["cluster"] = clusters
    noise = evaluate_noise(string_matrix)

    string_matrix = string_matrix.sort_values(by="cluster")
    dict_colors, unique_clusters = generate_dict_colors(string_matrix)

    header.remove("status")

    feature_frequency = Counter(); # Specialized container in collections, used to store the nof_occurrences of an element like a dictionary
    for _, row in string_matrix.iterrows():
        for feature in string_matrix.columns[1:-1].tolist():
            if row[feature] != "nan":
                feature_frequency[feature] += 1
        
    # Dash app
    plot_sankey(string_matrix, string_matrix_copy, distance_matrix, dict_colors, unique_clusters, header, feature_frequency, eps_opt, min_samples_opt, noise, knn_graph)


# Phase 1
# Set regression directory from the command line
parser = argparse.ArgumentParser(description='Parse .log files in a regression directory into a csv of run_names, used control flags [ECTB] and error_messages')
# The path to the regression directory is mandatory
parser.add_argument('-p', '--path', help='Path to the regression directory', required=True)
# Flag that enables successful run logs to be parsed
parser.add_argument('-u', '--use_passed', help='Enable successful run logs to be parsed', action='store_const', const=1, default=0)
# Flag that enables intermediary csv generation
parser.add_argument('-g', '--generate_csv', help='Generate the intermediary string and numeric matrices resulted from the parsing', action='store_const', const=1, default=0)
# Parse the arguments of the command
args = parser.parse_args()

# Get all run dictionaries
# List of dictionaries of all runs, with features and values
runs = []

# Walk through the directory tree
for root, dirs, files in os.walk(args.path):
    # Split the full path to the directory, and save the name of the furthest down folder
    base_dir = root.split('/')[-1]
    # Check if the base directory name starts with 'run_'
    if base_dir.startswith('run_'):
        # Iterate through all files in the current directory (root)
        # Found log
        for file in files:
            if file == 'xrun.log': # This makes the parser only compatible with Xcelium based regressions 
                # Name runs after their parent directory
                run = parse_log(base_dir, root + '/' + file)
                # If run uses ECTB correctly, add it to the list of dictionaries
                if (run != False):
                    if(run["status"] == "passed" and args.use_passed): 
                        runs.append(run)
                
                    elif(run["status"] != "passed"):
                        runs.append(run)

# First row of the matrix are the feature names
header = get_header(runs)
string_matrix = [header]; # This appends the header of the matrix

# Populate the matrix according to each run
for run in runs:
    row = []
    for feature in header:
        if feature in run:
            row.append(run[feature]) # Place the value of the flag for this run in the matrix correctly
        else:
            row.append("nan") # This run did not use this flag
    string_matrix.append(row)

# Sort the matrix runs based on their names (run_1, run_2, ...)
string_matrix[1:] = sorted(string_matrix[1:], key=lambda x: int(x[0].split('_')[-1]))

if(args.generate_csv):
    string_matrix_csv = "string_matrix.csv"

    # Write the matrix to a CSV file
    # String matrix used for sankey diagram
    with open(string_matrix_csv, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerows(string_matrix)

# Phase 2 & 3
string_matrix = pd.DataFrame(string_matrix[1:], columns=header)
string_matrix.set_index(string_matrix["run_name"], inplace=True)
string_matrix.drop(columns="run_name", inplace=True)

if len(string_matrix) > 0:
    cluster_and_visualize(string_matrix, header)
else:
    raise Exception("There is no regression dump at provided path.")