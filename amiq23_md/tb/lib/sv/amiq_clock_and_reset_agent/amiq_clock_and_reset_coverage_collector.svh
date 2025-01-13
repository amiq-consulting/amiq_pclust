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
// Description      : Clock and reset coverage collector. Measures information
//                    related to the clock and reset items
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_COVERAGE_COLLECTOR
`define AMIQ_CLOCK_AND_RESET_COVERAGE_COLLECTOR

class amiq_clock_and_reset_coverage_collector extends uvm_component;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_clock_and_reset_coverage_collector)

	// implement coverage collector analysis port as implementation port (receiving end)
	uvm_analysis_imp#(amiq_clock_and_reset_item, amiq_clock_and_reset_coverage_collector) monitor_ap;

	// counts number of resets
	int count = 0;
	// has initial reset flag
	bit has_first_reset = 0;

	// delay between consecutive resets
	covergroup reset_delay_cg with function sample(int delay);
		reset_delay_cp: coverpoint delay {
			bins short [] = {[1:`CLK_RST_MIN_RESET_THRESHOLD - 1]};
			bins mid [] = {[`CLK_RST_MIN_RESET_THRESHOLD:10]};
			bins big [10] = {[11:`CLK_RST_DELAY_MAX_VALUE - 1]};
			bins max [1] = {[`CLK_RST_DELAY_MAX_VALUE:$]};
		}
	endgroup

	// reset duration
	covergroup reset_length_cg with function sample(int length);
		reset_length_cp: coverpoint length {
			bins mid [] = {[`CLK_RST_MIN_RESET_THRESHOLD:5]};
			bins big [5] = {[6:15]};
			bins max [1] = {[16:$]};
		}
	endgroup

	// number of resets in a test
	covergroup number_of_resets_cg with function sample(int count);
		number_of_resets_cp: coverpoint count {
			bins initial_reset = {1};
			bins short [2] = {[2:8]};
			bins big [2] = {[9:15]};
			bins max [1] = {[16:$]};
		}
	endgroup

	function new(string name = "amiq_clock_and_reset_coverage_collector", uvm_component parent);
		super.new(name, parent);

		// create the port for valid clk_rst items
		monitor_ap = new("monitor_ap", this);

		// create and set the name for the reset_delay covergroup
		reset_delay_cg = new();
		reset_delay_cg.set_inst_name("reset_delay_cg");

		// create and set the name for the reset_length covergroup
		reset_length_cg = new();
		reset_length_cg.set_inst_name("reset_length_cg");

		// create and set the name for the number of resets covergroup
		number_of_resets_cg = new();
		number_of_resets_cg.set_inst_name(" number_of_resets_cg");

	endfunction

	function void check_phase(uvm_phase phase);
		super.check_phase(phase);
		// sample the number of resets at the end of test
		number_of_resets_cg.sample(count);
	endfunction

	// get item from clock and reset monitor
	function void write(amiq_clock_and_reset_item received_item);

		// sample the reset item's length
		reset_length_cg.sample(received_item.length);

		// sample the delay between two consecutive resets
		if (has_first_reset)
			reset_delay_cg.sample(received_item.delay);
		else
			has_first_reset = 1;

		// count every reset item
		count ++;
	endfunction

endclass

`endif // AMIQ_CLOCK_AND_RESET_COVERAGE_COLLECTOR
