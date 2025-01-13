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
// Description      : Package which includes all files relevant to the clock and reset agent
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_AGENT_PKG
`define AMIQ_CLOCK_AND_RESET_AGENT_PKG

package amiq_clock_and_reset_agent_pkg;

	// includes the text from all uvm macros
	`include "uvm_macros.svh"
	import uvm_pkg::*;

	`include "amiq_clock_and_reset_defines.svh"
	`include "amiq_clock_and_reset_config_obj.svh"
	`include "amiq_clock_and_reset_item.svh"
	`include "amiq_clock_and_reset_sequencer.svh"
	`include "amiq_clock_and_reset_sequence.svh"
	`include "amiq_clock_and_reset_monitor.svh"
	`include "amiq_clock_and_reset_coverage_collector.svh"
	`include "amiq_clock_and_reset_driver.svh"
	`include "amiq_clock_and_reset_agent.svh"

endpackage

`endif // AMIQ_CLOCK_AND_RESET_AGENT_PKG
