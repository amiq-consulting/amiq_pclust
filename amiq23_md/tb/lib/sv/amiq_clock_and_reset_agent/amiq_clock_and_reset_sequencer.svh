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
// Description      : Clock and reset sequencer. Coordinates transaction flow
//                  to the driver.
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_SEQUENCER
`define AMIQ_CLOCK_AND_RESET_SEQUENCER

class amiq_clock_and_reset_sequencer extends uvm_sequencer #(amiq_clock_and_reset_item);

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_clock_and_reset_sequencer)

	// configured clock period
	rand bit unsigned [7:0] configured_clock_period;

	function new (string name, uvm_component parent);
		super.new(name, parent);
	endfunction

endclass

`endif // AMIQ_CLOCK_AND_RESET_SEQUENCER
