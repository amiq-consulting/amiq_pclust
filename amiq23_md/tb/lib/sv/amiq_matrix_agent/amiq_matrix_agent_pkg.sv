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
// Creation Date    : Jul 28, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Package which includes all files relevant to the input agent
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_AGENT_PKG
`define AMIQ_MATRIX_AGENT_PKG

package amiq_matrix_agent_pkg;

	// includes the text from all uvm macros
	`include "uvm_macros.svh"
	import uvm_pkg::*;

	`include "amiq_matrix_defines.svh"

	// maximum and minimum values of a signed bus
	localparam MAT_UNDERFLOW_VALUE = (-1) * (2 ** `MAT_BUS_WIDTH) / 2;
	localparam MAT_OVERFLOW_VALUE = (-1 * MAT_UNDERFLOW_VALUE) - 1;

	`include "amiq_matrix_types.svh"
	`include "amiq_matrix_config_obj.svh"
	`include "amiq_matrix_item.svh"
	`include "amiq_matrix_sequencer.svh"
	`include "amiq_matrix_sequence.svh"
	`include "amiq_matrix_monitor.svh"
	`include "amiq_matrix_coverage_collector.svh"
	`include "amiq_matrix_driver.svh"
	`include "amiq_matrix_agent.svh"

endpackage

`endif // AMIQ_MATRIX_AGENT_PKG

