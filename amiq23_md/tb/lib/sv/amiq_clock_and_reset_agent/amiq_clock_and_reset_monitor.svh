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
// Description      : Clock and reset monitor. Packs low-level bus information
//                  into abstract items.
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_MONITOR
`define AMIQ_CLOCK_AND_RESET_MONITOR

class amiq_clock_and_reset_monitor extends uvm_monitor;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_clock_and_reset_monitor)

	// implement monitor analysis port (broadcasting end)
	uvm_analysis_port#(amiq_clock_and_reset_item) reset_ap;

	// the clock and reset virtual interface
	virtual amiq_clock_and_reset_if clk_rst_vif;

	// the monitored item
	amiq_clock_and_reset_item collected_item;

	//realtime variables used to measure clock period
	realtime start_time = 0;
	realtime end_time = 0;

	bit unsigned [7:0] measured_clock_period = 0;

	// delay until reset is active
	int unsigned pre_delay = 0;
	// reset length
	int unsigned length = 0;

	function new(string name = "amiq_clock_and_reset_monitor", uvm_component parent);
		super.new(name, parent);
		// create the reset analysis port
		reset_ap  = new("reset_ap", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// get the clock and reset agent virtual interface from uvm_config_db
		if (!uvm_config_db#(virtual amiq_clock_and_reset_if)::get(this, "", "clk_rst_if", clk_rst_vif))
			`uvm_fatal(get_name(), "Could not get the clk rst virtual interface handle.")
	endfunction

	virtual task run_phase(uvm_phase phase);

		start_time = $realtime();
		@(posedge clk_rst_vif.clock);
		end_time = $realtime();
		measured_clock_period = start_time - end_time;
		`uvm_info(get_name(), $sformatf("Monitored clock period: %d", measured_clock_period), UVM_FULL)
		forever begin
			pre_delay = 0;
			// measure pre delay
			while(clk_rst_vif.reset_n) begin
				@(posedge clk_rst_vif.clock);
				pre_delay ++;
			end

			length = 0;
			// measure length
			while(!clk_rst_vif.reset_n) begin
				@(posedge clk_rst_vif.clock);
				length ++;
			end

			// create the monitored item
			collected_item = amiq_clock_and_reset_item::type_id::create("collected_item", this);
			collected_item.delay = pre_delay;
			collected_item.length = length;
			`uvm_info(get_name(),  $sformatf("Clock and reset Monitor collected item: %s", collected_item.convert2string()), UVM_HIGH)

			// send collected item to the analysis port
			reset_ap.write(collected_item);
		end
	endtask
endclass

`endif // AMIQ_CLOCK_AND_RESET_MONITOR
