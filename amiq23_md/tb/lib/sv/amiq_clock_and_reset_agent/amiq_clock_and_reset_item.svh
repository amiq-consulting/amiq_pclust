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
// Description      : Clock and reset item. Abstractization of information
//                    from the clock and reset signals.
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_ITEM
`define AMIQ_CLOCK_AND_RESET_ITEM

class amiq_clock_and_reset_item extends uvm_sequence_item;

	// register this object in the UVM Factory
	`uvm_object_utils(amiq_clock_and_reset_item)

	// reset duration
	rand int length;

	// delay in cc before the reset
	rand int delay;

	// offset in ns from the posedge of clock for asynchronous resets
	rand int offset;

	// default values for an item
	constraint reset_c{
		soft length inside{[`CLK_RST_MIN_RESET_THRESHOLD:`CLK_RST_MAX_RESET_THRESHOLD]};
		soft delay inside{[0:`CLK_RST_DELAY_MAX_VALUE]};
		soft offset inside {[0:delay]};
	}

	function new(string name = "amiq_clock_and_reset_item");
		super.new(name);
	endfunction

	// Function to convert item to string
	function string convert2string();
		string content = "";
		$sformat(content, "%s delay: %d", content, delay);
		$sformat(content, "%s length: %d", content, length);
		$sformat(content, "%s offset: %d", content, offset);
		return content;
	endfunction

endclass

`endif // AMIQ_CLOCK_AND_RESET_ITEM
