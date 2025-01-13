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
// Description      :Package which includes all files relevant to the output agent
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_AGENT_PKG
`define AMIQ_DETERMINANT_AGENT_PKG

package amiq_determinant_agent_pkg;

	// includes the text from all uvm macros
	`include "uvm_macros.svh"
	import uvm_pkg::*;

	`include "amiq_determinant_defines.svh"

	// dynamic array of shortints
	typedef shortint amiq_det_queue_of_shortint_t[$];

	// maximum and minimum values of a 16bit signed bus
	localparam DET_UNDERFLOW_VALUE =(-1) * (2 ** `DET_BUS_WIDTH) / 2;
	localparam DET_OVERFLOW_VALUE =(-1 * DET_UNDERFLOW_VALUE) - 1;

	`include "amiq_determinant_config_obj.svh"
	`include "amiq_determinant_item.svh"
	`include "amiq_determinant_monitor.svh"
	`include "amiq_determinant_coverage_collector.svh"
	`include "amiq_determinant_agent.svh"

endpackage

`endif // AMIQ_DETERMINANT_AGENT_PKG

