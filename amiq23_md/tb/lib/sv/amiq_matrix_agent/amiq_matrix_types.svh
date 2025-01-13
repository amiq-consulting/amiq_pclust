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
// Creation Date    : Sep 14, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : File containing typedefs used in the agent
//---------------------------------------------------------------------------


// dynamic array of shortints
`ifndef AMIQ_MATRIX_TYPES
`define AMIQ_MATRIX_TYPES
typedef shortint amiq_matrix_queue_of_shortint_t[$];

// enum for driving x and z during data idle
typedef enum {HIGH_IMPEDANCE, UNKOWN} amiq_matrix_drive_idle_t;

// Stages of the transaction, when reset can happen
typedef enum { BEFORE_PACKET, DURING_PACKET, DURING_BACKPRESSURE} amiq_matrix_reset_stages_t; /* @DVT_LINTER_WAIVER "Generated Code Waiver" INFO SVTB.27.5.6 */

`endif // AMIQ_MATRIX_TYPES
