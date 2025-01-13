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
// Description      : Base test case, extended by all tests.
// WARNING: THIS TEST IS NOT SUPPOSED TO BE RAN.
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_BASE_TEST
`define AMIQ_MD_BASE_TEST

class amiq_md_base_test extends amiq_ectb_test;

	// register component in the UVM Factory
	`uvm_component_utils(amiq_md_base_test)

	amiq_md_env                 env;
	amiq_md_env_config_obj      env_cfg;

	function new(string name = "amiq_md_base_test", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// factory create the environment configuration, randomize it and set in the config db
		env_cfg = amiq_md_env_config_obj::type_id::create("env_cfg", this);

		//randomize environment configuration
		if (!randomize(env_cfg))
			`uvm_error(get_name(), "Couldn't randomize the environment configuration")

		uvm_config_db # (amiq_md_env_config_obj)::set (this, "env*", "env_cfg", env_cfg);

		// factory create the environment
		env = amiq_md_env::type_id::create("env", this);
		`uvm_info(get_name(), "Environment created", UVM_FULL)

	endfunction
	
	virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        virtual_sequencer = env.vseqr;
    endfunction : connect_phase
    
    
    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        super.run_phase(phase);
        phase.drop_objection(this);
	    uvm_test_done.set_drain_time(this, 400);
    endtask : run_phase
    
endclass

`endif // AMIQ_MD_BASE_TEST
