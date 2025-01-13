from itertools import combinations
from collections import Counter
import numpy as np
import pandas as pd 

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

def sum_of_products(mapping, used_flags, nof_min_elements, nof_max_elements):
    """For each generated subset, multiply the cardinal of each flag and compute the global sum of products.
    Args:
        mapping (dict): Dictionary mapping a flag to its possible values {flag : [values_of_flag]}.
        used_flags (list): List of all flags used in the sequence.
        nof_min_elements (int): Minimum number of elements in a subset.
        nof_max_elements (int): Maximum number of elements in a subset.

    Returns:
        Sum of all products.
    """
    sum_products = 0
    for subset in subsets_generator(used_flags, nof_min_elements, nof_max_elements):
        # Calculate the product of elements in the current subset
        product = 1
        for num in subset:
            product *= len(mapping[num])
        sum_products += product
    return sum_products

def generate_tests(plusargs_path, seq_name, seq_type, sequences, flags, used_values, current_depth, failed_runs):
    """Recursively generate tests for each distinct combination of flag values of a sequence.
    Args:
        plusargs_path (string): Path for the destination svh file to be written.
        seq_name (string): Name of the current sequence.
        sequences (dict): Dictionary mapping seq name to used flags.
        flags (dict): Dictionary mapping a flag to its possible values {flag : [values_of_flag]}.
        used_values (list): List of flag values used in the test.
        current_depth (int): Variable used to monitor recursion.
    """
    # Reached recursion stopping condition
    if(len(used_values) == len(sequences[seq_name])):
        global nof_tests
        # Write test plusarg file
        with open(plusargs_path + f"Test{nof_tests}.args", mode='w', newline='\n') as file:
            file.write(f"""+seq0={seq_type}\n+seq0_name={seq_name}\n""")
            for value in used_values:
                flag = value.split("[")[0]
                file.write(f"""+{seq_name}_{flag}={value}\n""")
            file.write("\n")
        nof_tests += 1
        return
    current_flag = list(sequences[seq_name])[current_depth]
    for i in range(len(flags[current_flag])):
        generate_tests(plusargs_path, seq_name, seq_type, sequences, flags, used_values + [current_flag + f"[{i}]"], current_depth + 1)

def dice_distance_matrix(runs_matrix):
    """Compute Dice distance between runs.
    Args:
        runs_matrix (DataFrame): Pandas DataFrame showing the parseg regression.

    Returns:
        Gower distances matrix.
    """
    N = len(runs_matrix)
    gower_matrix = np.zeros((N, N))
    header = list(runs_matrix.columns)
    for i in range(N - 1):
        for j in range(i + 1, N):
            a = set(k for k in runs_matrix.loc[f"run{i}"].tolist() if k != "N/A")
            b = set(k for k in runs_matrix.loc[f"run{j}"].tolist() if k != "N/A")
            #Dice Formula
            distance = 1 - 2 * len(a.intersection(b)) / (len(a) + len(b))
            gower_matrix[i, j] = gower_matrix[j, i] = distance
    return gower_matrix

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

def custom_distance(a, b, weights):
    intersection = [item for item in a if item in b]
    intersection_score = 0
    a_score = 0
    b_score = 0

    # Deal with error type
    to_remove = "N/A"
    for item in intersection:
        if item.startswith("error"):
            # Judge how to take into account same error type
            # intersection_score += 1
            to_remove = item
    if to_remove != "N/A":
        intersection.remove(to_remove)
        a.remove(to_remove)
        b.remove(to_remove)
    else:
        for item in a:
            if item.startswith("error"):
                to_remove = item
        a.remove(to_remove)
        for item in b:
            if item.startswith("error"):
                to_remove = item
        b.remove(to_remove)

    # Count scores
    for item in subsets_generator(intersection, 2, len(intersection)):
        if(weights[item] > 0):
            intersection_score += 1
    for item in subsets_generator(a, 2, len(a)):
        if(weights[item] > 0):
            a_score += 1
    for item in subsets_generator(b, 2, len(b)):
        if(weights[item] > 0):
            b_score += 1
    
    #Custom formula
    distance = 1 - 2 * intersection_score / (a_score + b_score + 0.0001)
    return distance


def custom_distance_matrix(runs_matrix, weights):
    
    """Compute similarity matrix based on a custom distance metric.
    Args:
        failed_matrix (DataFrame): Pandas DataFrame showing the failed runs of the regression.

    Returns:
        Similarity matrix.
    """
    failed_matrix = runs_matrix.copy()
    failed_matrix = failed_matrix[failed_matrix["status"] != "passed"]
    failed_matrix.reset_index(drop=True, inplace=True)
    # failed_matrix.drop(columns=["status"], inplace = True)
    N = len(failed_matrix)
    similarity_matrix = np.zeros((N, N))
    for i in range(N - 1):
        for j in range(i + 1, N):
            a = [k for k in failed_matrix.loc[i].tolist() if k != "nan"]
            b = [k for k in failed_matrix.loc[j].tolist() if k != "nan"]
            distance = custom_distance(a, b, weights)
            similarity_matrix[i, j] = similarity_matrix[j, i] = distance
    similarity_matrix = pd.DataFrame(similarity_matrix)        
    similarity_matrix.to_csv("similarity_matrix.csv", index = True, header = True)
    return similarity_matrix

# MDS
# mds = MDS(n_components= 6, dissimilarity="precomputed", random_state=69, normalized_stress=False)
# X = mds.fit_transform(distance_matrix)
# print(f"\nPreservation: {mds.stress_}")

# # Plot the points in 2D space
# plt.figure(figsize=(10, 8))
# plt.scatter(runs_2d[:, 0], runs_2d[:, 1])
# plt.title('Runs in 2D Euclidean Space')
# plt.grid(True)
# plt.show()