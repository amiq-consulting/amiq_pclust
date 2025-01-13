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
// Description      : Input driver. Responsible for unpacking the
//                    input item into low-level information
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_DRIVER
`define AMIQ_MATRIX_DRIVER

class amiq_matrix_driver extends uvm_driver#(amiq_matrix_item);

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_matrix_driver)

	// the input interface
	virtual amiq_matrix_if in_vif;

	// finished item flag
	bit finished_item = 0;

	// has initial reset flag
	bit has_init_reset = 0;

	// the handler of the get and drive thread
	process get_and_drive_process;
	// what kind of data is driven during both mat_request and mat_valid deasserted
	amiq_matrix_drive_idle_t idle_data = HIGH_IMPEDANCE;

	function new (string name = "amiq_matrix_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		// get the clock and reset agent virtual interface from uvm_config_db
		if (!uvm_config_db#(virtual amiq_matrix_if)::get(this, "", "input_if", in_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")
	endfunction

	virtual task run_phase(uvm_phase phase);
		forever begin
			fork
				reset_driver();
				begin
					get_and_drive_process = process::self();
					get_and_drive();
				end
			join
		end
	endtask

	// get the item from sequencer and drive it forward
	virtual task get_and_drive();
		// skip posedge of reset at time 0
		if(!has_init_reset)
			@(negedge in_vif.reset_n);

		@(posedge in_vif.reset_n);

		begin
			forever begin
				// get item from sequencer
				seq_item_port.get_next_item(req);

				// mark it as just started
				finished_item = 0;

				// drive the item
				drive_bus(req);

				`uvm_info(get_name(), $sformatf("sent: %s", req.convert2string()), UVM_HIGH)

				// mark it as finished
				finished_item = 1;

				// send item port done
				seq_item_port.item_done();
			end
		end
	endtask

	/**
	 * The function translates the input item into interface signals
	 *
	 * @param a_req - item from sequencer
	 */
	task drive_bus(amiq_matrix_item a_req);
		for( int i = 0; i < `MAT_MATRIX_SIZE ; i++)begin
			for( int j = 0 ; j < `MAT_MATRIX_SIZE ; j++) begin

				// wait for the required delay
				if(a_req.pre_element_delay[i][j]) begin
					in_vif.mat_valid <= 0;

					repeat (a_req.pre_element_delay[i][j]) begin
						@(posedge in_vif.clock);
						if(idle_data == HIGH_IMPEDANCE)
							in_vif.mat_in <= `MAT_BUS_WIDTH'bz;
						else if ( idle_data == UNKOWN)
							in_vif.mat_in <= `MAT_BUS_WIDTH'bx;
					end
				end

				in_vif.mat_valid <= 1;
				in_vif.mat_in <= a_req.matrix[i][j];

				// correctly evaluate mat_request with if
				@(posedge in_vif.clock);

				// keep data stable until 1 cc after request asserts
				// if request is already 1, this means skipping just one clock period was ok
				while (!in_vif.mat_request)
					@(posedge in_vif.clock);
			end
		end

		// deassert mat_valid at the end of an item
		in_vif.mat_valid <= 0;
	endtask

	// bring all local variables to initial state
	function void reset_local_variables();

		in_vif.mat_valid <= 0;
		if (!has_init_reset)
			has_init_reset = 1;

	endfunction

	// reset the driver
	virtual task reset_driver();
		@(negedge in_vif.reset_n);
		
		if (get_and_drive_process != null) begin
			get_and_drive_process.kill();
		end
		if (!finished_item && has_init_reset) begin
			finished_item = 1;
			seq_item_port.item_done();
		end
		
		reset_local_variables();

	endtask

endclass

`endif // AMIQ_MATRIX_DRIVER
