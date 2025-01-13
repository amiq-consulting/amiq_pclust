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
// Description      : Output item. Abstractization of information
//                    from the output interface signals.
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_ITEM
`define AMIQ_DETERMINANT_ITEM

class amiq_determinant_item extends uvm_sequence_item;

	// the result of the determinant
	rand bit signed [`DET_BUS_WIDTH - 1:0] determinant;

	// saturation flag
	rand bit overflow;

	// delay between results
	rand int pre_det_delay;

	// register this object in the UVM Factory
	`uvm_object_utils_begin(amiq_determinant_item)
		`uvm_field_int(determinant, UVM_ALL_ON)
		`uvm_field_int(overflow, UVM_ALL_ON + UVM_UNSIGNED)
		`uvm_field_int(pre_det_delay, UVM_ALL_ON + UVM_NOCOMPARE + UVM_UNSIGNED)
	`uvm_object_utils_end


	function new(string name = "amiq_determinant_item");
		super.new(name);
	endfunction

	// Function to convert item to string
	function string convert2string();
		string content = "";
		$sformat(content, "%s determinant: %h", content, determinant);
		$sformat(content, "%s saturated: %b", content, overflow);
		$sformat(content, "%s pre_result_delay: %d", content, pre_det_delay);
		return content;
	endfunction
endclass

`endif // AMIQ_DETERMINANT_ITEM
