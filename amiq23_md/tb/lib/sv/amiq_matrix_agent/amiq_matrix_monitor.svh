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
// Description      : Input monitor. Packs low-level bus information
//                  into abstract items.
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_MONITOR
`define AMIQ_MATRIX_MONITOR

class amiq_matrix_monitor extends uvm_monitor;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_matrix_monitor)

	// implement monitor analysis port for valid items (broadcasting end)
	uvm_analysis_port#(amiq_matrix_item) valid_ap;
	// implement monitor analysis port for invalid items (broadcasting end)
	uvm_analysis_port#(shortint) invalid_ap;

	// the input virtual interface
	virtual amiq_matrix_if in_vif;

	// the valid monitored item
	amiq_matrix_item collected_valid_item;

	// the handler of the valid monitoring thread
	process valid_process;
	// the handler of the invalid bus value monitoring thread
	process invalid_process;

	// variable used to measure pre matrix element delay
	int pre_delay = 0;
	// flag that marks the initial reset
	bit has_init_reset = 0;

	function new(string name = "amiq_matrix_monitor", uvm_component parent);
		super.new(name, parent);
		// create the valid analysis port
		valid_ap  = new("valid_ap", this);
		// create the invalid analysis port
		invalid_ap  = new("invalid_ap", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// get the input agent virtual interface from uvm_config_db
		if (!uvm_config_db#(virtual amiq_matrix_if)::get(this, "", "input_if", in_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")
	endfunction

	virtual task run_phase(uvm_phase phase);
		forever begin
			fork
				reset_monitor();

				begin
					// get process PID
					valid_process = process::self();
					monitor_valid_item();
				end

				begin
					// get process PID
					invalid_process = process::self();
					monitor_invalid_item();
				end
			join
		end
	endtask

	// monitor the valid item
	virtual task monitor_valid_item();

		if(!has_init_reset)
			@(negedge in_vif.reset_n);
		@(posedge in_vif.reset_n);

		forever begin
			// create the monitored item
			collected_valid_item = amiq_matrix_item::type_id::create("collected_valid_item", this);
			for (int i = 0 ; i < `MAT_MATRIX_SIZE; i++) begin
				for( int j = 0; j < `MAT_MATRIX_SIZE; j++) begin
					pre_delay = 0;
					// skip one posedge clock to correctly evalueate mat_request and mat_valid
					@(posedge in_vif.clock);
					while(!in_vif.mat_request || !in_vif.mat_valid) begin
						@(posedge in_vif.clock);
						pre_delay ++;
					end
					collected_valid_item.pre_element_delay[i][j] = pre_delay;
					collected_valid_item.matrix[i][j] = in_vif.mat_in;
				end
			end
			`uvm_info(get_name(), $sformatf("Input Monitor collected item: %s", collected_valid_item.convert2string()), UVM_HIGH)
			// write item in valid port
			valid_ap.write(collected_valid_item);
			@(posedge in_vif.mat_request);
		end
	endtask

	// monitor the invalid bus value
	virtual task monitor_invalid_item();

		if(!has_init_reset)
			@(negedge in_vif.reset_n);
		@(posedge in_vif.reset_n);

		forever begin
			@(posedge in_vif.clock);
			while(in_vif.mat_valid || !in_vif.mat_request)
				@(posedge in_vif.clock);
			invalid_ap.write(in_vif.mat_in);
		end

	endtask

	function void reset_local_variables();
		pre_delay = 0;
		if(!has_init_reset)
			has_init_reset = 1;
	endfunction

	// reset the monitor
	task reset_monitor();

		@(negedge in_vif.reset_n);

		`uvm_info(get_name(), "Reseting input monitor", UVM_HIGH)

		if (valid_process != null)
			valid_process.kill();

		if (invalid_process != null)
			invalid_process.kill();

		reset_local_variables();
	endtask

endclass

`endif // AMIQ_MATRIX_MONITOR
