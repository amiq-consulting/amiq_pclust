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
// Description      : Output agent, wrapper for all components that
//                    maneuver the output items
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_AGENT
`define AMIQ_DETERMINANT_AGENT

class amiq_determinant_agent extends uvm_agent;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_determinant_agent)

	amiq_determinant_config_obj         cfg;
	amiq_determinant_monitor            monitor;
	amiq_determinant_coverage_collector coverage_collector;


	function new (string name = "amiq_determinant_agent", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get configuration from uvm_config_db
		if (!uvm_config_db # (amiq_determinant_config_obj)::get (this, "", "output_agent_cfg", cfg))
			`uvm_fatal(get_name(), "Configuration cannot be retrieved")

		// building the monitor
		monitor            = amiq_determinant_monitor::type_id::create("monitor", this);
		`uvm_info(get_name(), "Monitor created", UVM_FULL)
		if (cfg.has_coverage) begin
			coverage_collector = amiq_determinant_coverage_collector::type_id::create("coverage_collector", this);
			`uvm_info(get_name(), "Coverage collector created", UVM_FULL)
		end
		if (cfg.is_active == UVM_ACTIVE) begin
			`uvm_info(get_name(), "Driver and sequencer created", UVM_FULL)
		end
	endfunction

	// connect the output agent components
	function void connect_phase(uvm_phase phase);

		// connect monitor to coverage collector
		if (cfg.has_coverage) begin
			monitor.valid_ap.connect(coverage_collector.valid_ap);
			monitor.invalid_ap.connect(coverage_collector.invalid_ap);
			`uvm_info(get_name(), "Out Monitor connected to out CC", UVM_HIGH)
		end
		// connect sequencer to driver
		if (cfg.is_active == UVM_ACTIVE) begin
			`uvm_info(get_name(), "Driver and sequencer connected", UVM_HIGH)
		end
	endfunction

endclass

`endif // AMIQ_DETERMINANT_AGENT
