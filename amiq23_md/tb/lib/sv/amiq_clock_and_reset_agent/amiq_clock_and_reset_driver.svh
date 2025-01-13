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
// Description      : Clock and reset driver. Responsible for unpacking the
//                    clock and reset item into low-level information
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_DRIVER
`define AMIQ_CLOCK_AND_RESET_DRIVER

class amiq_clock_and_reset_driver extends uvm_driver#(amiq_clock_and_reset_item);

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_clock_and_reset_driver)

	// clock period in ns
	bit unsigned [7:0] period = 20;

	// the clock and reset virtual interface
	virtual amiq_clock_and_reset_if clk_rst_vif;

	function new (string name = "amiq_clock_and_reset_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// get the clock and reset agent virtual interface from uvm_config_db
		if (!uvm_config_db#(virtual amiq_clock_and_reset_if)::get(this, "", "clk_rst_if", clk_rst_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")
	endfunction

	virtual task run_phase(uvm_phase phase);
		// handle clock generation and get_and_drive in parallel
		fork
			// generate clock
			begin
				clk_rst_vif.clock <= 0;
				// after one period, clock value should be the same
				forever #(period / 2) clk_rst_vif.clock <= !clk_rst_vif.clock;
			end
			// get item and drive it
			begin
				get_and_drive();
			end
		join
	endtask

	// get sequence and drive it
	virtual task get_and_drive();
		forever begin
			seq_item_port.get_next_item(req);
			`uvm_info(get_name(), $sformatf("sent: %s", req.convert2string()), UVM_HIGH)
			drive(req);
			seq_item_port.item_done();
		end
	endtask

	// drive the sequence
	virtual task drive(amiq_clock_and_reset_item a_req);
		// start reset as inactive
		clk_rst_vif.reset_n <= 1;

		// wait for the corresponding delay
		repeat (a_req.delay)
			@(posedge clk_rst_vif.clock);

		# a_req.offset;

		// hold reset active for the corresponding length
		clk_rst_vif.reset_n <= 0;

		// in case of async reset, length is monitorable from the next posedge
		if(a_req.offset)
			@(posedge clk_rst_vif.clock);

		repeat (a_req.length)
			@(posedge clk_rst_vif.clock);

		// deassert reset
		clk_rst_vif.reset_n <= 1;
	endtask
endclass

`endif // AMIQ_CLOCK_AND_RESET_DRIVER
