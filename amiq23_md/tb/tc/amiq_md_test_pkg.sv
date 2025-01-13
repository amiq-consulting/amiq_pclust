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
// Description      : Package which includes all files relevant to the tests
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_TEST_PKG
`define AMIQ_MD_TEST_PKG

package amiq_md_test_pkg;

	import uvm_pkg::*;
	`include "uvm_macros.svh"
	
	import amiq_ectb_pkg::*;
	import amiq_md_env_pkg::*;
	import amiq_md_seq_pkg::*;
	
	`include "amiq_md_base_test.svh"

endpackage

`endif // AMIQ_MD_TEST_PKG

