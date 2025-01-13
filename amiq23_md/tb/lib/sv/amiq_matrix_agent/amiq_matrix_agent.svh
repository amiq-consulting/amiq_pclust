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
// Description      : Input agent, wrapper for all components that
//                    maneuver the input items
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_AGENT
`define AMIQ_MATRIX_AGENT

class amiq_matrix_agent extends uvm_agent;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_matrix_agent)

	amiq_matrix_config_obj            cfg;
	amiq_matrix_driver             driver;
	amiq_matrix_sequencer          sequencer;
	amiq_matrix_monitor            monitor;
	amiq_matrix_coverage_collector coverage_collector;

	function new (string name = "amiq_matrix_agent", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get configuration from uvm_config_db
		if (!uvm_config_db # (amiq_matrix_config_obj)::get (this, "", "input_agent_cfg", cfg))
			`uvm_fatal(get_name(), "Configuration  cannot be retrieved")

		// building the monitor
		monitor            = amiq_matrix_monitor::type_id::create("monitor", this);
		`uvm_info(get_name(), "Monitor created", UVM_FULL)

		// building the coverage collector
		if (cfg.has_coverage) begin
			coverage_collector = amiq_matrix_coverage_collector::type_id::create("coverage_collector", this);
			`uvm_info(get_name(), "Coverage collector created", UVM_FULL)
		end

		// building the sequencer and driver
		if (cfg.is_active == UVM_ACTIVE) begin
			sequencer          = amiq_matrix_sequencer::type_id::create("sequencer", this);
			`uvm_info(get_name(), "Sequencer created", UVM_FULL)
			driver             = amiq_matrix_driver::type_id::create("driver", this);
			driver.idle_data = cfg.idle_data;
			`uvm_info(get_name(), "Driver created", UVM_FULL)
		end
	endfunction

	// connect the clk_rst agent components
	function void connect_phase(uvm_phase phase);

		// connect monitor to coverage collector
		if (cfg.has_coverage) begin
			monitor.valid_ap.connect(coverage_collector.valid_ap);
			monitor.invalid_ap.connect(coverage_collector.invalid_ap);
			`uvm_info(get_name(), "Monitor connected to coverage collector", UVM_HIGH)
		end
		// connect sequencer to driver
		if (cfg.is_active == UVM_ACTIVE) begin
			driver.seq_item_port.connect(sequencer.seq_item_export);
			`uvm_info(get_name(), "Driver connected to sequencer", UVM_HIGH)
		end
	endfunction

endclass

`endif // AMIQ_MATRIX_AGENT
