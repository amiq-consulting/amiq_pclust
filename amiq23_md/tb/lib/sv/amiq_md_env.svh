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
// Description      : Environment, wrapper containing all verification components
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_ENV
`define AMIQ_MD_ENV

class amiq_md_env extends uvm_env;

	// register the component in the UVM Factory
	`uvm_component_utils(amiq_md_env)

	amiq_clock_and_reset_agent               clk_rst_agent;
	amiq_matrix_agent                 input_agent;
	amiq_determinant_agent                output_agent;
	amiq_md_scoreboard                  scbd;
	amiq_md_block_coverage_collector    coverage_collector;
	amiq_md_virtual_sequencer           vseqr;
	amiq_md_env_config_obj              env_cfg;

	function new(string name = "amiq_md_env", uvm_component parent);
		super.new(name, parent);
	endfunction

	// building the environment components
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get environment configuration
		if (!uvm_config_db # (amiq_md_env_config_obj)::get (this, "", "env_cfg", env_cfg))
			`uvm_fatal(get_name(), "Environment configuration cannot be retrieved")

		// set clk and reset configuration
		uvm_config_db #(amiq_clock_and_reset_config_obj)::set(this, "clk_rst_agent*", "clk_rst_agent_cfg", env_cfg.clk_rst_agent_cfg);

		// set input configuration
		uvm_config_db #(amiq_matrix_config_obj)::set(this, "input_agent*", "input_agent_cfg", env_cfg.input_agent_cfg);

		// set output configuration
		uvm_config_db #(amiq_determinant_config_obj)::set(this, "output_agent*", "output_agent_cfg", env_cfg.output_agent_cfg);

		// create clk and rst agent
		`uvm_info(get_name(), "Clock and Reset Agent created", UVM_HIGH)
		clk_rst_agent  = amiq_clock_and_reset_agent::type_id::create("clk_rst_agent", this);

		// create input agent
		input_agent   = amiq_matrix_agent::type_id::create("input_agent", this);
		`uvm_info(get_name(), "Input Agent created", UVM_HIGH)

		// create output agent
		output_agent  = amiq_determinant_agent::type_id::create("output_agent", this);
		`uvm_info(get_name(), "Output Agent created", UVM_HIGH)

		// create the virtual sequencer
		vseqr         = amiq_md_virtual_sequencer::type_id::create("vseqr", this);
		`uvm_info(get_name(), "Virtual Sequencer created", UVM_HIGH)
		vseqr.env_cfg = env_cfg;

		// create the scoreboard
		scbd        = amiq_md_scoreboard::type_id::create("scbd", this);
		`uvm_info(get_name(), "Scoreboard created", UVM_HIGH)

		if (env_cfg.has_coverage) begin
			coverage_collector          = amiq_md_block_coverage_collector::type_id::create("coverage_collector", this);
			`uvm_info(get_name(), "Block coverage collector created", UVM_HIGH)
		end
	endfunction

	// connect the environment components
	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		// connect the virtual sequencer to the physical input agent one
		if (env_cfg.input_agent_cfg.is_active == UVM_ACTIVE)
			vseqr.in_sequencer = input_agent.sequencer;

		// connect the virtual sequencer to the physical clk and rst agent one
		if (env_cfg.clk_rst_agent_cfg.is_active == UVM_ACTIVE)
			vseqr.clk_rst_sequencer = clk_rst_agent.sequencer;

		if (env_cfg.output_agent_cfg.is_active == UVM_ACTIVE)
			`uvm_fatal(get_name(), "Output agent in active")

		if(env_cfg.has_checks) begin
			// connect the clock and reset agent monitor to the scoreboard
			clk_rst_agent.monitor.reset_ap.connect(scbd.reset_port);
			// connect the input agent monitor to the scoreboard
			input_agent.monitor.valid_ap.connect(scbd.expected_port);
			// connect the output agent monitor to the scoreboard
			output_agent.monitor.valid_ap.connect(scbd.collected_port);
		end

		if (env_cfg.has_coverage) begin
			// connect input agent to block coverage collector
			input_agent.monitor.valid_ap.connect(coverage_collector.input_ap);
			// connect output agent to block coverage collector
			output_agent.monitor.valid_ap.connect(coverage_collector.output_ap);
		end

	endfunction

	task run_phase(uvm_phase phase);
		// set configuration in the env components
		env_cfg.set_config();

	endtask
endclass

`endif // AMIQ_MD_ENV
