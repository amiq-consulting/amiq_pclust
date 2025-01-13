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
// Description      : Package which includes all files relevant to the environment
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_ENV_PKG
`define AMIQ_MD_ENV_PKG

package amiq_md_env_pkg;

	import uvm_pkg::*;
	`include "uvm_macros.svh"
	
	`include "amiq_md_defines.svh"
	`include "amiq_md_types.svh"
	
	/**
	 * @param i - Computes the factorial of the given integer
	 */
	function automatic longint factorial(longint i);
		longint result = 1;
		if(i)
			result = i * factorial(i - 1);
		else
			result = 1;
		return result;
	endfunction
	
	import amiq_ectb_pkg::*;
	import amiq_clock_and_reset_agent_pkg::*;
	import amiq_matrix_agent_pkg::*;
	import amiq_determinant_agent_pkg::*;

	`include "amiq_md_env_config_obj.svh"
	`include "amiq_md_block_coverage_collector.svh"
	`include "amiq_md_virtual_sequencer.svh"
	`include "amiq_md_scoreboard.svh"
	`include "amiq_md_env.svh"

endpackage

`endif // AMIQ_MD_ENV_PKG

