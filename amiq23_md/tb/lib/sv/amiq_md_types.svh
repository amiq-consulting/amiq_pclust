//----------------------------------------------------------------------------
//                                                                          --
//     COPYRIGHT (C)                                AMIQ 2023               --
//     The document(s) may be used  and/or copied only with the written     --
//     permission from AMIQ or in accordance with the terms and             --
//     conditions  stipulated in the agreement/contract under which the     --
//     document(s) have been supplied.                                      --
//                                                                          --
//----------------------------------------------------------------------------
// Created by       : andbli
// Creation Date    : Sep 6, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : <short description of the component/object>
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_TYPES
`define AMIQ_MD_TYPES

// dynamic array of shortints
typedef shortint amiq_queue_of_shortint_t[$];

// Stages of the input, when reset can happen
typedef enum { BEFORE_1, AFTER_1, AFTER_2, AFTER_3, AFTER_4,          /* @DVT_LINTER_WAIVER "Generated Code Waiver" DISABLE SVTB.31.1.0 */
	AFTER_5, AFTER_6, AFTER_7, AFTER_8} amiq_input_stages_t; /* @DVT_LINTER_WAIVER "Generated Code Waiver" DISABLE SVTB.31.1.0 */

// Stages of the output, when reset can happen
typedef enum { BEFORE_VALID, DURING_VALID, DURING_OVERFLOW} amiq_output_stages_t;

// interesting values that can be all the same on a row/column
typedef enum {NO_SAME_VALUE_ON_ROW_COLUMN, MINUS_ONE, ZERO, ONE, OTHER} amiq_row_column_t;

// types of triangular matrices
typedef enum {NOT_TRIANGULAR, UPPER, LOWER} amiq_triangular_t;

// types of permutation matrices
typedef enum {NOT_PERMUTATION, IDENTITY, PERMUTATIONS} amiq_permutations_t;

// types of b2b transfers
typedef enum { NOT_B2B, STANDARD_B2B, EXTREME_B2B} amiq_type_of_b2b_t;

`endif // AMIQ_MD_TYPES


