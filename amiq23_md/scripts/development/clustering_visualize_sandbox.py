import numpy as np
import pandas as pd
import math
import colorsys
from collections import Counter
from misc import subsets_generator
from misc import compute_weights
from sklearn.cluster import DBSCAN
from sklearn.cluster import HDBSCAN
from sklearn.cluster import OPTICS
from sklearn.neighbors import NearestNeighbors
import plotly.graph_objects as go
import plotly.io as pio
import dash
from dash import dcc, html, Input, Output, State, dash_table
from dash.exceptions import PreventUpdate

def dice_distance_matrix(failed_matrix):
    """Compute Dice distance between runs.
    Args:
        failed_matrix (DataFrame): Pandas DataFrame showing the parseg regression.

    Returns:
        Dice distances matrix.
    """
    dummy = failed_matrix.copy()
    dummy.reset_index(drop=True, inplace=True)
    N = len(dummy)
    dice_matrix = np.zeros((N, N))
    header = list(dummy.columns)
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

def clustering_performance(failed_matrix):
    
    # Expected clusters
    real_clusters = {}
    for index, row in failed_matrix.iterrows():
        if row["bug"] not in real_clusters:
            real_clusters[row["bug"]] = []
        real_clusters[row["bug"]].append(index)

    # Predicted clusters
    predicted_clusters = failed_matrix.groupby("cluster").apply(lambda x: x.index.tolist()).to_dict()
    # Evaluate noise
    nof_noise = failed_matrix[failed_matrix["cluster"] == -1].shape[0]
    noise_score = nof_noise / len(failed_matrix)
    failed_matrix = failed_matrix[failed_matrix["cluster"] != -1].copy()
    
    # Prioritize large clusters
    sorted_bugs = sorted(real_clusters.items(), key=lambda x: len(x[1]), reverse=True)
    precisions = []
    recalls = []
    cluster_assigned = set()
    for bug, runs in sorted_bugs:
        # Find the cluster with the best overlap with this bug
        best_cluster, best_overlap = -1, 0
        for cluster, cluster_runs in predicted_clusters.items():
            if cluster in cluster_assigned or cluster == -1:
                continue
            overlap = len(set(runs) & set(cluster_runs))
            if overlap > best_overlap:
                best_cluster, best_overlap = cluster, overlap

        # Calculate precision and recall for this bug
        cluster_assigned.add(best_cluster)
        precision = best_overlap / len(predicted_clusters[best_cluster]) if best_cluster != -1 else 0
        recall = best_overlap / len(runs) if len(runs) > 0 else 0
        precisions.append(precision)
        recalls.append(recall)
        
    # Average precision and recall across all bugs
    avg_precision = sum(precisions) / len(precisions)
    avg_recall = sum(recalls) / len(recalls)

    # F1 score
    if avg_precision or avg_recall:
        f1_score = 2 * (avg_precision * avg_recall) / (avg_precision + avg_recall)
    else:
        f1_score = 0

    return [noise_score, f1_score]

def get_optimum_eps(distance_matrix, k=None):
    """Get the optimum eps value for this dataset, given as a distance matrix.
    Args:
        distance_matrix (DataFrame): Similarity measure between all runs, given as a simetric matrix.

    Returns:
        Optimum eps and knn graph.
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

        # Create an array of indices to represent the x values
        x = np.arange(len(values))
        y = np.array(values)

        # Calculate curvature
        curvature = list(calculate_curvature(x, y))

        plateau_index = -1
        # Find the index of the first 0 curvature, values[index] != 0   
        for i, curv in enumerate(curvature):
            if curv == 0 and values[i] != 0:
                plateau_index = i
                break

        if plateau_index == -1:
            plateau_index = len(values) // 2
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

def generate_pastel_colors(num_colors):
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
    unique_clusters = sorted(list(set(failed_matrix["cluster"])))
    dict_colors = {-1:'#000000'}

    if -1 in unique_clusters:
        unique_clusters.remove(-1)
    pastel = generate_pastel_colors(len(unique_clusters))

    for i in range(len(unique_clusters)):
        dict_colors[i] = pastel[i]
    return dict_colors, unique_clusters

# GUI
def plot_sankey(failed_matrix, failed_matrix_copy, distance_matrix, dict_colors, unique_clusters, regression_features, feature_frequency):

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
    global eps_opt
    global min_samples_opt
    global perf
    global knn_graph

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
            clustered_runs.drop(columns="bug", inplace = True)
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
            html.Div(id="performance-output", children=f"Noise: {round(perf[0], 2)} F1_Score: {round(perf[1], 2)}", style={'textAlign': 'center', 'marginBottom': '20px'}),
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
         Output('performance-output', 'children'),
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
                regression_features = sorted(failed_matrix.columns[2:-1].tolist(), key=lambda x: (-feature_frequency[x], x))
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

        # Evaluate clustering
        perf = clustering_performance(failed_matrix_copy)
        
        return [
            sankey_fig,
            table_fig,
            f"Selected eps:{round(eps_value, 4)}",
            f"Selected minPts:{pts_value}",
            f"Noise:{round(perf[0], 2)}    F1_Score:{round(perf[1], 2)}",
            [{'label': f"bug_{i}", 'value': i} for i in unique_clusters],
            unique_clusters[0] if len(unique_clusters) else None,
            eps_style
            ]

    # Run the Dash app
    app.run_server(debug=True)

###########################################################
# Main

runs_matrix = pd.read_excel("sandbox_matrix.xlsx", index_col=0).astype(str)

# Get the failed tests
failed_matrix = runs_matrix[runs_matrix["status"] != "passed"].copy()
failed_matrix.index.name = "run_name"

# print(f"failed_matrix: \n{failed_matrix}")

failed_matrix_copy = failed_matrix.copy()
# Prepare failed matrix for similarity measure
for i in failed_matrix_copy.index.tolist():
    for col in failed_matrix_copy.columns.tolist():
        if col != "status" and col != "bug" and failed_matrix_copy.loc[i, col] != "nan":
            failed_matrix_copy.loc[i, col] = col  + "_" + failed_matrix_copy.loc[i, col]

# Default clustering
# Compute similarity measure
distance_matrix = dice_distance_matrix(failed_matrix_copy)
nof_dimensions = len(failed_matrix_copy.columns) - 2

# Optimize hyperparameters
min_samples_opt = math.ceil(np.log(len(failed_matrix))) # Heuristic default approach
if min_samples_opt < 2:
    min_samples_opt = 2

eps_opt, knn_graph = get_optimum_eps(distance_matrix=distance_matrix, k = int(np.sqrt(len(failed_matrix)))) # Heuristic k

# Cluster and evaluate clustering
clusters = cluster(eps_opt, min_samples_opt, "DBSCAN", distance_matrix)
failed_matrix["cluster"] = clusters
failed_matrix_copy["cluster"] = clusters

failed_matrix = failed_matrix.sort_values(by="cluster")
dict_colors, unique_clusters = generate_dict_colors(failed_matrix)
perf = clustering_performance(failed_matrix_copy)

# Default order, most hits first
feature_frequency = Counter(); # Specialized container in collections, used to store the nof_occurrences of an element like a dictionary
for _, row in failed_matrix.iterrows():
    for feature in failed_matrix.columns[2:-1].tolist():
        if row[feature] != "nan":
            feature_frequency[feature] += 1

regression_features = sorted(failed_matrix.columns[2:-1].tolist(), key=lambda x: (-feature_frequency[x], x))
regression_features = ["run_name"] + regression_features

# Dash app
plot_sankey(failed_matrix, failed_matrix_copy, distance_matrix, dict_colors, unique_clusters, regression_features, feature_frequency)