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
// Description      : Clock and reset sequence. Controls the physical transactions.
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_SEQUENCE
`define AMIQ_CLOCK_AND_RESET_SEQUENCE

class amiq_clock_and_reset_sequence extends uvm_sequence#(amiq_clock_and_reset_item);

	// register this object in the UVM Factory
	`uvm_object_utils(amiq_clock_and_reset_sequence)
	// declare pointer to clock and reset sequencer
	`uvm_declare_p_sequencer(amiq_clock_and_reset_sequencer)

	// has asynchronous reset
	rand bit asynchronous;

	// item to be randomized
	rand amiq_clock_and_reset_item clk_rst_item;

	// default values for the min and max delay
	constraint reset_seq_c{

		soft clk_rst_item.delay inside {[1 : `CLK_RST_DELAY_MAX_VALUE]};
		soft clk_rst_item.length inside{[`CLK_RST_MIN_RESET_THRESHOLD:`CLK_RST_MAX_RESET_THRESHOLD]};
		if(asynchronous)
			clk_rst_item.offset inside {[0:p_sequencer.configured_clock_period - 1]};
		else
			clk_rst_item.offset == 0;
	}

	function new(string name = "amiq_clock_and_reset_sequence");
		super.new(name);

		clk_rst_item = amiq_clock_and_reset_item::type_id::create("clk_rst_item");

	endfunction

	task body();
		// randomize, create and start the clock and reset sequence
		`uvm_send(clk_rst_item)
	endtask

endclass

`endif // AMIQ_CLOCK_AND_RESET_SEQUENCE
