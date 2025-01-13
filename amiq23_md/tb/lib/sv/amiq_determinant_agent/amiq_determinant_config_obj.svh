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
// Creation Date    : Aug 2, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Configuration fot the output agent
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_CONFIG_OBJ
`define AMIQ_DETERMINANT_CONFIG_OBJ

class amiq_determinant_config_obj extends uvm_object;

	// register this object in the UVM Factory
	`uvm_object_utils(amiq_determinant_config_obj)

	// field that marks if agent is passive or active
	rand uvm_active_passive_enum is_active = UVM_PASSIVE;

	// flag that enables/disables coverage in the agent
	rand bit has_coverage ;
	// flag that enables/disables checking in the agent
	rand bit has_checks ;

	// default values for config fields
	constraint output_config_c{
		soft has_coverage == 1;
		soft has_checks == 1;
		soft is_active == UVM_PASSIVE;
	}

	function new(string name = "amiq_clock_and_reset_config_obj");
		super.new(name);
	endfunction

endclass

`endif // AMIQ_DETERMINANT_CONFIG_OBJ
