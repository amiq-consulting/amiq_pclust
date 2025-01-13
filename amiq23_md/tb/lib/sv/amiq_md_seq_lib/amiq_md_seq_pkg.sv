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
// Creation Date    : Oct 24, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : <short description of the component/object>
//----------------------------------------------------------------------------

package amiq_md_seq_pkg;

	import uvm_pkg::*;
	`include "uvm_macros.svh"
	import amiq_ectb_pkg::*;
	import amiq_matrix_agent_pkg::*;
	import amiq_clock_and_reset_agent_pkg::*;
	import amiq_md_env_pkg::*;
	`include "amiq_md_base_seq.svh"
	`include "amiq_md_special_seq.svh"

endpackage
