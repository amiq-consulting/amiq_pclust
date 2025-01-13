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
// Creation Date    : Aug 17, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Configuration for the environment
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_ENV_CONFIG_OBJ
`define AMIQ_MD_ENV_CONFIG_OBJ

class amiq_md_env_config_obj extends uvm_object;

	// register this object in the UVM Factory
	`uvm_object_utils(amiq_md_env_config_obj)

	// field that marks if environment is passive or active
	rand uvm_active_passive_enum is_active = UVM_ACTIVE;

	// flag that enables/disables environment coverage
	rand bit has_coverage ;
	// flag that enables/disables environment checks
	rand bit has_checks ;

	// input agent configuration object
	rand amiq_matrix_config_obj input_agent_cfg;

	// output agent configuration object
	rand amiq_determinant_config_obj output_agent_cfg;

	// clock and reset agent configuration object
	rand amiq_clock_and_reset_config_obj clk_rst_agent_cfg;

	virtual amiq_md_sva_if sva_vif;
	virtual amiq_matrix_if mat_vif;
	virtual amiq_determinant_if det_vif;
	virtual amiq_clock_and_reset_if clk_rst_vif;

	// default env config fields values
	constraint env_config_c{
		soft has_coverage == 1;
		soft has_checks == 1;
		soft is_active == UVM_ACTIVE;
	}

	function new(string name = "amiq_md_env_config_obj");
		super.new(name);

		clk_rst_agent_cfg   = amiq_clock_and_reset_config_obj::type_id::create("clk_rst_agent_cfg");
		input_agent_cfg   = amiq_matrix_config_obj::type_id::create("input_agent_cfg");
		output_agent_cfg   = amiq_determinant_config_obj::type_id::create("output_agent_cfg");

	endfunction

	/**
	 * set information throughout env
	 */
	function void set_config();

		if (!uvm_config_db#(virtual amiq_md_sva_if)::get(null, "*env", "sva_if", sva_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")

		if (!uvm_config_db#(virtual amiq_matrix_if)::get(null, "*input_agent", "input_if", mat_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")

		if (!uvm_config_db#(virtual amiq_determinant_if)::get(null, "output_agent", "output_if", det_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")

		if (!uvm_config_db#(virtual amiq_clock_and_reset_if)::get(null, "clk_rst_agent", "clk_rst_if", clk_rst_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")

		if(!has_checks) begin
			clk_rst_agent_cfg.has_checks = 0;
			input_agent_cfg.has_checks = 0;
			output_agent_cfg.has_checks = 0;
			sva_vif.has_checks = 0;
			mat_vif.has_checks = 0;
			det_vif.has_checks = 0;
			clk_rst_vif.has_checks = 0;
		end
		if(!has_coverage) begin
			clk_rst_agent_cfg.has_coverage = 0;
			input_agent_cfg.has_coverage = 0;
			output_agent_cfg.has_coverage = 0;
		end
		if(is_active == UVM_PASSIVE) begin
			clk_rst_agent_cfg.is_active = UVM_PASSIVE;
			input_agent_cfg.is_active = UVM_PASSIVE;
		end
	endfunction
endclass

`endif // AMIQ_MD_ENV_CONFIG_OBJ
