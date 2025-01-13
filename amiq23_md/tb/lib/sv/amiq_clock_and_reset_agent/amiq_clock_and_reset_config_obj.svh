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
// Creation Date    : Aug 17, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Configuration for the clock and reset agent.
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_CONFIG_OBJ
`define AMIQ_CLOCK_AND_RESET_CONFIG_OBJ

class amiq_clock_and_reset_config_obj extends uvm_object;

	// register this object in the UVM Factory
	`uvm_object_utils(amiq_clock_and_reset_config_obj)

	// field that marks if agent is passive or active
	rand uvm_active_passive_enum is_active = UVM_ACTIVE;

	// flag that enables/disables coverage in the agent
	rand bit has_coverage ;
	// flag that enables/disables checking in the agent
	rand bit has_checks ;

	// set clock period for the UVC
	rand bit unsigned [7:0] configured_clock_period;

	// default values for config fields
	constraint clk_rst_config_c{

		soft has_coverage == 1;
		soft has_checks == 1;
		soft is_active == UVM_ACTIVE;
		// set default clock period for 20 ns
		soft configured_clock_period == 20;
	}

	function new(string name = "amiq_clock_and_reset_config_obj");
		super.new(name);
	endfunction

endclass

`endif // AMIQ_CLOCK_AND_RESET_CONFIG_OBJ

