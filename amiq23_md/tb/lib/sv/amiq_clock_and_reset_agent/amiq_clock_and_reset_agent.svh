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
// Description      : Clock and reset agent, wrapper for all components that
//                    maneuver the clock and reset items
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_AGENT
`define AMIQ_CLOCK_AND_RESET_AGENT

class amiq_clock_and_reset_agent extends uvm_agent;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_clock_and_reset_agent)

	amiq_clock_and_reset_config_obj            cfg;
	amiq_clock_and_reset_driver             driver;
	amiq_clock_and_reset_sequencer          sequencer;
	amiq_clock_and_reset_monitor            monitor;
	amiq_clock_and_reset_coverage_collector coverage_collector;

	function new (string name = "amiq_clock_and_reset_agent", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get configuration from uvm_config_db
		if (!uvm_config_db # (amiq_clock_and_reset_config_obj)::get (this, "", "clk_rst_agent_cfg", cfg))
			`uvm_fatal(get_name(), "Configuration cannot be retrieved")

		// building the monitor
		monitor            = amiq_clock_and_reset_monitor::type_id::create("monitor", this);
		`uvm_info(get_name(), "Monitor created", UVM_FULL)

		// building the coverage collector
		if (cfg.has_coverage) begin
			coverage_collector = amiq_clock_and_reset_coverage_collector::type_id::create("coverage_collector", this);
			`uvm_info(get_name(), "Coverage collector created", UVM_FULL)
		end

		// building the sequencer and driver
		if (cfg.is_active == UVM_ACTIVE) begin
			sequencer          = amiq_clock_and_reset_sequencer::type_id::create("sequencer", this);
			sequencer.configured_clock_period = cfg.configured_clock_period;
			`uvm_info(get_name(), "Sequencer created", UVM_FULL)
			driver             = amiq_clock_and_reset_driver::type_id::create("driver", this);
			`uvm_info(get_name(), "Driver created", UVM_FULL)
			driver.period = cfg.configured_clock_period;
		end
	endfunction

	// connect the clk_rst agent components
	function void connect_phase(uvm_phase phase);

		// connect monitor to coverage collector
		if (cfg.has_coverage) begin
			monitor.reset_ap.connect(coverage_collector.monitor_ap);
			`uvm_info(get_name(), "Monitor connected to coverage collector", UVM_HIGH)
		end

		// connect sequencer to driver
		if (cfg.is_active == UVM_ACTIVE) begin
			driver.seq_item_port.connect(sequencer.seq_item_export);
			`uvm_info(get_name(), "Driver connected to sequencer", UVM_HIGH)
		end
	endfunction

endclass

`endif // AMIQ_CLOCK_AND_RESET_AGENT
