import argparse
import random
import glob
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import os
from misc import subsets_generator
from misc import sum_of_products

# Main parser
parser = argparse.ArgumentParser(
    description='Generate random combinations of control flag values that could produce a bug')
parser.add_argument('--config', type=str,
                    help='Name of excel file with sandbox configuration')
parser.add_argument('--nof_max_bugs_in_error', type=int,
                    help='Number of maximum bugs that can relate to the same assertion', default=2)
parser.add_argument('--seed', type=int,
                    help='Seed used for randomization', default=0)
parser.add_argument('--auto_parse', type=int,
                    help='Get the failed runs matrix directly from the generated errors model', default=1)
parser.add_argument('--auto_regression', type=int,
                    help='Generate svas, plusargs and vrsf', default=0)
args = parser.parse_args()  # Parse the remaining arguments

# Assign seed to pseudo-random number generator
random.seed(args.seed)

# Set up configs
auto_parse = args.auto_parse
auto_regression = args.auto_regression
config_file = args.config
config = pd.read_excel(config_file, sheet_name=None)

# Dictionary showing each flag and its possible values
flags = dict()
nof_flags = len(config["Flags"])
for i in range(nof_flags):
    row = config["Flags"].loc[i].tolist()
    row = [item for item in row if not pd.isna(item)]
    flags[row[0]] = row[1:]


# List of all sequences in the regression, showing their used flags
sequences = dict()
nof_sequences = len(config["Sequences"])

nof_runs = []
for i in range(nof_sequences):
    row = config["Sequences"].loc[i].tolist()
    row = [item for item in row if not pd.isna(item)]
    nof_runs.append(row[1])
    sequences[row[0]] = row[2:]

print(f"\nnof_flags: {nof_flags}")
print(f"nof_sequences: {nof_sequences}")

# Bug details
nof_max_bugs_in_error = args.nof_max_bugs_in_error
nof_bugs = len(config["Bugs"])
bug_names = []
nof_flags_in_bugs = []
bug_seq_types = []

for i in range(nof_bugs):
    row = config["Bugs"].loc[i].tolist()
    bug_names.append(row[0])
    nof_flags_in_bugs.append(row[1])
    bug_seq_types.append(row[2])
print(f"nof_bugs: {nof_bugs}")


def generate_bug(flags, sequences, bug_seq_type, nof_flags_in_bug):
    """Generate a random combination of flag values that could produce a bug 
    Args:
        flags (dict): Dictionary mapping a flag to its possible values {flag : [values_of_flag]}.
        sequences (dict): Dictionary mapping seq name to used flags.
        bug_seq_type (string): String showing the sequence for the bug. If not specified, it is randomly assigned.
        nof_flags_in_bug (int): Number of flags that generate the bug.
    Returns:
        Dictionary of flags that compose a bug.
    """
    if not pd.isna(bug_seq_type):
        sequence = bug_seq_type
    else:
        sequence = random.choice(list(sequences.keys()))
    chosen_flags = random.sample(list(sequences[sequence])[
                                 1:], k=nof_flags_in_bug)
    bug = dict()
    bug["seq"] = sequence
    for flag in flags:
        if (flag in chosen_flags):
            bug[flag] = random.choice(flags[flag])
        elif (flag in sequences[sequence]):
            bug[flag] = "any"
        else:
            bug[flag] = "N/A"
    return bug


def generate_model(flags, nof_max_bugs_in_error, bugs):
    """Generate a random matrix model showcasing the bugs <-> errors correspondence. 
    Args:
        flags (dict): Dictionary mapping a flag to its possible values {flag : [values_of_flag]}.
        nof_max_bugs_in_error (int): Maximum number of errors that can be associated with a bug.
        bugs (dict): Dictionary of flags that compose a bug.

    Returns:
       Model matrix, a pandas DataFrame showing bugs to errors correspondence.
    """
    # Generate an empty frame for the matrix
    header = []
    header.append("bug")
    header.append("error")
    for flag in flags.keys():
        header.append(flag)
    header.append("seq")

    sequences = sorted(list(set(bugs[bug]["seq"] for bug in bugs)))
    assertion_matrix = pd.DataFrame(columns=header)
    unassigned_bugs = dict()
    for seq in sequences:
        seq_bugs = []
        for bug in bugs:
            if bugs[bug]["seq"] == seq:
                seq_bugs.append(bug)
        unassigned_bugs[seq] = seq_bugs

    nof_errors = 0
    nof_entries = 0
    finished = False
    # Randomly populate the matrix according to the bugs
    while finished == False:
        have_seq = False
        potential_sequences = sequences.copy()
        random.shuffle(potential_sequences)
        while have_seq == False:
            chosen_seq = potential_sequences.pop()
            if (len(unassigned_bugs[chosen_seq]) > 0):
                have_seq = True

        nof_bugs_in_error = random.randrange(1, nof_max_bugs_in_error + 1)
        if nof_bugs_in_error > len(unassigned_bugs[chosen_seq]):
            nof_bugs_in_error = len(unassigned_bugs[chosen_seq])

        chosen_bugs = random.sample(
            unassigned_bugs[chosen_seq], k=nof_bugs_in_error)
        for bug in chosen_bugs:
            unassigned_bugs[chosen_seq].remove(bug)
            assertion_matrix.loc[nof_entries, "error"] = f"error{nof_errors}"
            for item in list(bugs[bug].keys()):
                assertion_matrix.loc[nof_entries, item] = bugs[bug][item]
            assertion_matrix.loc[nof_entries, "bug"] = bug
            nof_entries += 1

        nof_errors += 1
        finished = True
        for seq in sequences:
            if (len(unassigned_bugs[seq]) > 0):
                finished = False

    def count_dots(row):
        return (row == "any").sum()

    assertion_matrix['dot_count'] = assertion_matrix.apply(count_dots, axis=1)

    # Sort the DataFrame by grouping on the "error" column and sorting within each group based on the count of "any"
    sorted_assertion_matrix = assertion_matrix.sort_values(by=["dot_count"])

    # Compute the total number of dots for each name
    total_dots = sorted_assertion_matrix.groupby(
        'error')['dot_count'].sum().reset_index()
    total_dots = total_dots.rename(columns={'dot_count': 'total_dot_count'})

    # Merge the total dots back into the original dataframe
    sorted_assertion_matrix = sorted_assertion_matrix.merge(
        total_dots, on='error')

    # Sort the dataframe by the total number of dots and then by name
    sorted_assertion_matrix = sorted_assertion_matrix.sort_values(
        by=['total_dot_count', 'error', 'dot_count'])

    # Drop the helper columns used for sorting
    sorted_assertion_matrix = sorted_assertion_matrix.drop(
        columns=['dot_count', 'total_dot_count'])

    sorted_assertion_matrix.reset_index(drop=True, inplace=True)
    print(f"\nthe assertions matrix:\n{sorted_assertion_matrix}")
    return sorted_assertion_matrix


def convert_model_to_binary(assertion_matrix, flags):
    """Convert the assertions matrix into a binary model, where each flag value is assigned a bit (exists or not in error). 
    Args:
        assertion_matrix (DataFrame): Model matrix, a pandas DataFrame showing bugs to errors correspondence.

    Returns:
        Binary matrix resulted from the conversion.
    """

    errors = sorted(list(set(assertion_matrix["error"])))
    # The sum of all flag cardinals
    nof_individual_flag_values = 0
    for flag in flags:
        nof_individual_flag_values += len(flags[flag])

    # List of all individual flag values
    values = ["error"]
    for flag in flags:
        for value in flags[flag]:
            values.append(flag + "_" + value)
    values.append("seq")
    # Initialize matrix with zeros
    binary_matrix = pd.DataFrame(np.zeros(
        (len(assertion_matrix), nof_individual_flag_values + 2), dtype='B'), columns=values)
    binary_matrix["error"] = binary_matrix["error"].astype(str)
    binary_matrix["seq"] = binary_matrix["seq"].astype(str)
    for i in range(len(assertion_matrix)):
        binary_matrix.loc[i, "error"] = assertion_matrix.loc[i, "error"]
        binary_matrix.loc[i, "seq"] = assertion_matrix.loc[i, "seq"]
        for flag in flags.keys():
            # If flag exists in error
            if (assertion_matrix.loc[i, flag] != "any" and assertion_matrix.loc[i, flag] != "N/A"):
                binary_matrix.loc[i, flag + "_" +
                                  assertion_matrix.loc[i, flag]] = 1
    # print(f"\n binary_matrix:\n{binary_matrix}")
    return binary_matrix


def generate_svas(sequences, flags, binary_matrix):
    """Generate SVAs for each error in the binary matrix, in the designated sequence file.
    Args:
        sequences (dict): Dictionary mapping seq name to used flags.
        flags (dict): Dictionary mapping a flag to its possible values {flag : [values_of_flag]}.
        binary_matrix (DataFrame): Pandas DataFrame of randomly generated bug <-> errors correspondence.
    """
    # Open file in write mode
    for s in sequences:
        # Write a custom sva file for each sequence
        with open(f"{s}_svas.svh", mode='w', newline='\n') as file:
            # The cardinals of the used flags in this sequence
            this_seq_nof_flags_values = []
            for flag in list(sequences[s])[1:]:
                this_seq_nof_flags_values.append(len(flags[flag]))
            # We need to translate the registered plusargs into binary codes, one code per flag
            file.write(
                f"""bit[{max(this_seq_nof_flags_values)} - 1 : 0] flag_codes [{len(this_seq_nof_flags_values)}]= '{{""")
            for i in range(len(this_seq_nof_flags_values) - 1):
                file.write("0, ")
            file.write(f"0}};\n")
            # For loop that converts used flags into codes
            # If flag0 has 3 values, and in this test it uses the value flag0[0]
            # Then flag_codes[i][j] = 3'b001
            content = f"""\nfor (int i = 0 ; i < {len(this_seq_nof_flags_values)}; i++) begin\n\tint j;\n\t$sscanf(flags[i], "val_%d", j);
\tflag_codes[i][j] = 1'b1;\nend\n"""
            file.write(content)
            # Filter out assertions that can't be achieved by this sequence
            filtered_matrix = binary_matrix.copy()
            filtered_matrix = filtered_matrix[filtered_matrix["seq"] == s].copy(
            )
            filtered_matrix.drop(columns=["seq"], inplace=True)

            prev_error = ""
            has_first_error = 0
            # Generate SVAs based on binary matrix
            for i in filtered_matrix.index.tolist():
                error = filtered_matrix.loc[i, "error"]
                if error != prev_error:
                    if has_first_error:
                        file.write(
                            f""")) else \n \t$error("{prev_error}");\n""")
                    else:
                        has_first_error = 1
                    file.write(f"\n{error}: assert((")
                else:
                    file.write(") && (")
                has_first_flag = 0
                j = 0
                for flag in list(sequences[s])[1:]:
                    # Join all bits of the same flag into a single code, value[0] being the LSB
                    bits = []
                    for value in flags[flag]:
                        column = flag + "_" + value
                        bits.append(str(filtered_matrix.loc[i, column]))
                    bits = bits[::-1]
                    flag_code = "".join(bits)
                    if (int(flag_code)):
                        if has_first_flag:
                            file.write(" || ")
                        else:
                            has_first_flag = 1
                        # Write SVA based on the used flags codes, from the tb, and the ones generated by the script
                        file.write(
                            f"flag_codes[{j}] != {this_seq_nof_flags_values[j]}'b{flag_code}")
                    j += 1
                prev_error = error
            file.write(f""")) else \n \t$error("{prev_error}");\n""")


def parse_possible_failed_runs(assertion_matrix, flags, error, run, current_depth):
    """Generate all possible failed runs. Development speed-up, appends in global possible_failed_runs DataFrame.
    Args:
        assertion_matrix (DataFrame): Model matrix, a pandas DataFrame showing bugs to errors correspondence.
    """
    global possible_failed_runs
    # Reached end of flags
    if (current_depth == len(assertion_matrix.loc[error]) - 1):
        # Append run
        possible_failed_runs.loc[len(possible_failed_runs)] = run
        return
    # This is a flag
    if (assertion_matrix.loc[error, assertion_matrix.columns[current_depth]] == "any"):
        for i in flags[assertion_matrix.columns[current_depth]]:
            parse_possible_failed_runs(
                assertion_matrix, flags, error, run + [i], current_depth + 1)
    else:
        parse_possible_failed_runs(assertion_matrix, flags, error, run + [
                                   assertion_matrix.loc[error, assertion_matrix.columns[current_depth]]], current_depth + 1)


def generate_random_tests(nof_runs, sequences, flags, auto_parse, auto_regression):
    """Generate random tests. This will act as a regression to test the clustering on.
    Args:
        nof_runs (list): Container showing the nof_runs to be generated for each sequence.
    """
    seq_number = 0
    global test_number
    global runs_matrix
    if (auto_parse):
        global possible_failed_runs
    for s in sequences:
        nof_seq_tests = nof_runs[seq_number]
        for i in range(nof_seq_tests):
            used_values = []
            for flag in list(sequences[s])[1:]:
                chosen_value = random.choice(flags[flag])
                if (auto_parse):
                    runs_matrix.loc[test_number, flag] = chosen_value
                used_values.append(chosen_value)

            if (auto_parse):
                failed = False
                for j in range(len(possible_failed_runs)):
                    if (list(possible_failed_runs.loc[j])[2:] == list(runs_matrix.loc[test_number])[2:]):
                        runs_matrix.loc[test_number,
                                        "status"] = possible_failed_runs.loc[j, "error"]
                        runs_matrix.loc[test_number,
                                        "bug"] = possible_failed_runs.loc[j, "bug"]
                        failed = True
                        break
                if not failed:
                    runs_matrix.loc[test_number, "status"] = "passed"
            if (auto_regression):
                with open(plusargs_path + f"Test{test_number}.args", mode='w', newline='\n') as file:
                    file.write(
                        f"""+seq0={list(sequences[s])[0]}\n+seq0_name={s}\n""")  # ECTB convention
                    k = 0
                    for flag in sequences[s][1:]:
                        file.write(f"""+{s}_{flag}={used_values[k]}\n""")
                        k += 1
                    file.write("\n")
            test_number += 1
        seq_number += 1


def generate_vrsf(nof_runs, relative_regression_path, relative_plusargs_path, vrsf_path):
    """Include all generated plusarg files in a to be written vrsf file.
    Args:
        nof_runs (int): Number of total tests in regression.
        relative_regression_path (string): Relative path to $PROJ_HOME, to the regression dump.
        relative_plusargs_path (string): Relative path to $PROJ_HOME, to the plusargs.
        vrsf_path (string):  Path for the destination vrsf file to be written.
    """
    with open(vrsf_path + f"pclust.vrsf", mode='w', newline='\n') as file:
        file.write(f"""session amiq_pclust_reg {{\n\ttop_dir: "$ENV(PROJ_HOME){relative_regression_path}";\n\toutput_mode: terminal;
\tpre_session_script: "$ENV(PROJ_HOME)/sim/compile.sh $DIR(session)";\n\tqueuing_policy: round_robin;\n}};\n\ngroup amiq23_md_tests {{	
\tscan_script: "vm_scan.pl shell.flt ius.flt ovm_sv_lib.flt vm.flt";\n\trun_script: "xrun +UVM_TESTNAME=amiq_md_base_test -svseed $ATTR(seed) $ATTR(top_files) -f $ENV(PROJ_HOME)/sim/sim.options -licqueue";
\ttimeout: 120;\n\n""")
        for i in range(nof_runs):
            file.write(
                f"""\ttest amiq_pclust_test{i} {{\n\t\ttop_files: "-f $ENV(PROJ_HOME){relative_plusargs_path}Test{i}.args";\n\t\tseed: random;\n\t\tcount: 1;\n\t}};\n""")
        file.write("};")


# STATS
# The total number of possible combinations of flags
# Not needed, nice additional info
nof_flag_combinations = 0
for seq in sequences:
    # Don't count seq type
    nof_flag_combinations += len(subsets_generator(
        sequences[seq][1:], 2, len(sequences[seq]) - 1))
print(
    f"\nTotal number of possible flag combinations to produce a bug is: {nof_flag_combinations}")

# Total possible value of flags combinations
# Not needed, nice additional info
nof_flag_values_combinations = 0
for seq in sequences:
    nof_flag_values_combinations += sum_of_products(
        flags, sequences[seq][1:], 2, len(sequences[seq]) - 1)
print(
    f"Total possible combinations of flag values to produce a bug is: {nof_flag_values_combinations}")

# Dictionary, mapping the bug name to the bug dict
bugs = dict()
nof_generated = 0
# Each bug is a dictionary, mapping a flag to the value it takes in order to trigger the bug
while nof_generated < nof_bugs:
    bug = generate_bug(
        flags, sequences, bug_seq_types[nof_generated], nof_flags_in_bugs[nof_generated])
    # Make sure the planets didn't align and we didn't generate the exactly same bug twice
    exists = False
    for existing_bug in bugs.keys():
        nof_matches = 0
        for flag in flags:
            if ((bug[flag] == bugs[existing_bug][flag]) or (bug[flag] == "N/A" and bugs[existing_bug][flag] == "any") or (bug[flag] == "any" and bugs[existing_bug][flag] == "N/A")):
                nof_matches += 1
        if (nof_matches == nof_flags):
            exists = True
            break
    if not exists:
        bugs[bug_names[nof_generated]] = bug
        nof_generated += 1

# Display bugs as a pandas DataFrame
show_bugs = pd.DataFrame(columns=list(flags.keys()) + ["seq"], index=bug_names)
for bug in bugs:
    show_bugs.loc[bug] = bugs[bug]
# Keep the first column as is and sort the rest based on number
# print(f"\nthe generated bugs:\n{show_bugs}")

assertion_matrix = generate_model(flags, nof_max_bugs_in_error, bugs)

if (auto_regression):
    binary_matrix = convert_model_to_binary(assertion_matrix, flags)

    # Delete previously generated svh files
    files = glob.glob("*.svh")
    for f in files:
        os.remove(f)

    generate_svas(sequences, flags, binary_matrix)

if (auto_parse):
    # Create a void frame for the failed runs matrix
    header = list(assertion_matrix.columns)
    header.remove("seq")

    possible_failed_runs = pd.DataFrame(columns=header)
    # Recursively generate each possible failed run for each assertion
    for i in assertion_matrix.index.tolist():
        parse_possible_failed_runs(assertion_matrix, flags, i, [], 0)
    # Runs will fail only with the first encountered error
    possible_failed_runs.drop_duplicates(subset=list(flags), inplace=True)
    possible_failed_runs.reset_index(drop=True, inplace=True)

    # print(f"\npossible_failed_runs:\n{possible_failed_runs}")

    header = ["bug"] + ["status"] + list(flags)
    runs_matrix = pd.DataFrame(
        "N/A", index=range(sum(nof_runs)), columns=header)

if (auto_regression):
    relative_plusargs_path = "/tb/tc/plusargs/"
    plusargs_path = os.environ['PROJ_HOME'] + relative_plusargs_path
    
    os.makedirs(plusargs_path, exist_ok=True)

    # Delete current plusargs folder contents
    files = glob.glob(plusargs_path + "*")
    for f in files:
        os.remove(f)

test_number = 0
# Generate tests for each sequence
generate_random_tests(nof_runs, sequences, flags, auto_parse, auto_regression)

if (auto_regression):
    # Generate a vrsf that includes all generated tests
    vrsf_path = os.environ['PROJ_HOME'] + "/tb/lib/reg/"

    os.makedirs(vrsf_path, exist_ok=True)

    relative_regression_path = "/sim/regression"

    os.makedirs(os.environ['PROJ_HOME'] + relative_regression_path, exist_ok=True)

    generate_vrsf(test_number, relative_regression_path,
                  relative_plusargs_path, vrsf_path)

if (auto_parse):
    runs_matrix.index = [f"run_{i}" for i in range(len(runs_matrix))]
    runs_matrix.to_excel("sandbox_matrix.xlsx", index=True)
