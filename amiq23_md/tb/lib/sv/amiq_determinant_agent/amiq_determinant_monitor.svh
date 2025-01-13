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
// Description      : Output monitor. Packs low-level bus information
//                  into abstract items.
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_MONITOR
`define AMIQ_DETERMINANT_MONITOR

class amiq_determinant_monitor extends uvm_monitor;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_determinant_monitor)

	// implement monitor analysis port for valid items (broadcasting end)
	uvm_analysis_port#(amiq_determinant_item) valid_ap;
	// implement monitor analysis port for invalid items (broadcasting end)
	uvm_analysis_port#(bit signed [`DET_BUS_WIDTH - 1:0]) invalid_ap;

	// the output virtual interface
	virtual amiq_determinant_if out_vif;
	// the valid monitored item
	amiq_determinant_item collected_valid_item;


	// the handler of the valid monitor thread
	process valid_process;
	// the handler of the invalid monitor thread
	process invalid_process;

	// variable used to measure pre determinant delay
	int pre_delay = 0;
	// flag that marks the first reset
	bit has_init_reset = 0;

	function new(string name = "amiq_determinant_monitor", uvm_component parent);
		super.new(name, parent);
		// create the valid analysis port
		valid_ap  = new("valid_ap", this);
		// create the invalid analysis port
		invalid_ap  = new("invalid_ap", this);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		// get the input agent virtual interface from uvm_config_db
		if (!uvm_config_db#(virtual amiq_determinant_if)::get(this, "", "output_if", out_vif))
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
			@(negedge out_vif.reset_n);
		@(posedge out_vif.reset_n);

		forever begin

			pre_delay = 0;
			@(posedge out_vif.clock);
			// wait for valid
			while(!out_vif.det_valid) begin
				@(posedge out_vif.clock);
				pre_delay ++;
			end

			// create the monitored item
			collected_valid_item = amiq_determinant_item::type_id::create("collected_valid_item", this);
			collected_valid_item.pre_det_delay = pre_delay;
			collected_valid_item.determinant = out_vif.det;
			collected_valid_item.overflow = out_vif.overflow;

			`uvm_info(get_name(), $sformatf("Output Monitor collected item: %s", collected_valid_item.convert2string()), UVM_HIGH)
			valid_ap.write(collected_valid_item);
		end
	endtask

	// monitor the invalid data
	virtual task monitor_invalid_item();

		if(!has_init_reset)
			@(negedge out_vif.reset_n);
		@(posedge out_vif.reset_n);

		forever begin

			if (!out_vif.det_valid) begin
				invalid_ap.write(out_vif.det);
			end
			@(negedge out_vif.det_valid);
		end
	endtask

	function void reset_local_variables();
		pre_delay = 0;
	endfunction

	// reset the output monitor
	task reset_monitor();

		@(negedge out_vif.reset_n);
		`uvm_info(get_name(), "Reseting output monitor", UVM_HIGH)

		if(!has_init_reset)
			has_init_reset = 1;

		if (valid_process != null)
			valid_process.kill();

		if (invalid_process != null)
			invalid_process.kill();

		reset_local_variables();

	endtask

endclass

`endif // AMIQ_DETERMINANT_MONITOR
