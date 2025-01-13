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
// Creation Date    : Aug 1, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : <short description of the component/object>
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_VIRTUAL_SEQUENCER
`define AMIQ_MD_VIRTUAL_SEQUENCER

class amiq_md_virtual_sequencer extends uvm_sequencer;

	// register component in UVM Factory
	`uvm_component_utils(amiq_md_virtual_sequencer)

	// the physical input sequencer
	amiq_matrix_sequencer in_sequencer;

	// the physical output sequencer
	amiq_clock_and_reset_sequencer clk_rst_sequencer;

	// environment configuration
	amiq_md_env_config_obj env_cfg;

	function new(string name = "amiq_md_virtual_sequencer", uvm_component parent);
		super.new(name, parent);
	endfunction

endclass

`endif // AMIQ_MD_VIRTUAL_SEQUENCER
