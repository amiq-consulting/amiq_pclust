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
// Description      : Input coverage collector. Measures information
//                    related to the input items
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_COVERAGE_COLLECTOR
`define AMIQ_MATRIX_COVERAGE_COLLECTOR

// cover values of data_in bus
covergroup amiq_matrix_values_cg with function sample(bit signed [`MAT_BUS_WIDTH - 1:0] bus);
	mat_value_cp: coverpoint bus {
		bins max = {MAT_OVERFLOW_VALUE};
		bins min = {MAT_UNDERFLOW_VALUE};
		bins all_values [100] = {[MAT_UNDERFLOW_VALUE + 1 : MAT_OVERFLOW_VALUE - 1]};
		bins walking_one [] = generate_walking_one_bins();
	}
endgroup

/**
 *
 * @return generate bins for walking one pattern
 */
function amiq_matrix_queue_of_shortint_t generate_walking_one_bins(); /* @DVT_LINTER_WAIVER "Generated Code Waiver -this a systemverilog functionality" DISABLE SVTB.12.2.8 */
	automatic shortint generated_pattern = 0;
	for ( int i = 0 ; i < `MAT_BUS_WIDTH ; i++) begin
		generated_pattern = `MAT_BUS_WIDTH'b1 << i;
		generate_walking_one_bins.push_back(generated_pattern);
	end
endfunction

// cover distance between mat_valid assertion and mat_request assertion
covergroup amiq_packet_gap_cg with function sample(int unsigned gap);
	packet_gap_cp: coverpoint gap {
		bins short [] = {[0:5]};
		bins mid [5] = {[6:20]};
		bins big [10] = {[21:`MAT_DELAY_MAX_VALUE - 1]};
		bins max [1] = {[`MAT_DELAY_MAX_VALUE:$]};
	}
endgroup

// cover delay between signal assertions
covergroup amiq_delay_between_assertions_cg with function sample(int unsigned delay);
	signal_delay_cp: coverpoint delay {
		bins short [] = {[0:5]};
		bins mid [5] = {[5:20]};
		bins big [10] = {[21:`MAT_DELAY_MAX_VALUE - 1]};
		bins max [1] = {[`MAT_DELAY_MAX_VALUE:$]};
	}
endgroup

// cover signal length
covergroup amiq_length_cg with function sample(int unsigned length);
	signal_length_cp: coverpoint length {
		bins short [] = {[1:5]};
		bins mid [] = {[6:20]};
		bins big [10] = {[20:`MAT_LENGTH_MAX_VALUE - 1]};
		bins max [1] = {[`MAT_LENGTH_MAX_VALUE:$]};
	}
endgroup


class amiq_matrix_coverage_collector extends uvm_component;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_matrix_coverage_collector)

	// declares valid items analysis port
	`uvm_analysis_imp_decl(_valid_ap)

	// declares invalid items analysis port
	`uvm_analysis_imp_decl(_invalid_ap)

	// implements coverage collector valid items analysis port as implementation port (receiving end)
	uvm_analysis_imp_valid_ap #(amiq_matrix_item, amiq_matrix_coverage_collector) valid_ap;

	// implements coverage collector invalid items analysis port as implementation port (receiving end)
	uvm_analysis_imp_invalid_ap #(shortint, amiq_matrix_coverage_collector) invalid_ap;

	// input monitor virtual interface
	virtual amiq_matrix_if in_vif;

	// flag that marks a input packet is ongoing
	bit packet_started = 0;

	// flag that marks that the first request came
	bit has_first_req = 0;

	// flag that marks that the first valid came
	bit has_first_valid = 0;

	// flag that marks the occurance of the first reset
	bit has_init_reset = 0;

	// variables used to count deassertions mid packet
	int unsigned count_req = 0;
	int unsigned count_valid = 0;

	// process handlers
	process measure_process;

	// variables used to measure request length and delay
	int unsigned req_duration = 0;
	int unsigned req_delay = 0;

	// variables used to measure valid length and delay
	int unsigned valid_duration = 0;
	int unsigned valid_delay = 0;

	// variables used to measure inter packet delay, intra packet delay and burst length
	/*
	 * DIFFERENT TYPES OF DELAYS
	 *  INTER - how long does valid have to wait for request
	 *  INTRA - how long request has to wait for valid
	 *  BURST - how long valid and request are both asserted
	 *
	 @WAVEDROM_START
	 {signal: [
	 {name: 'clk', wave: 'p..............'},
	 {name: 'mat_valid', wave: '0...1.......0.1'},
	 {name: 'mat_request', wave: '1..0.1.0..1....'},
	 ]}
	 @WAVEDROM_END
	 */

	// variables used to measure aforementioned delays
	int unsigned inter_gap = 0;
	int unsigned intra_gap = 0;
	int unsigned burst_duration = 0;

	amiq_matrix_values_cg valid_matrix_values_cg;
	amiq_matrix_values_cg invalid_matrix_values_cg;

	amiq_delay_between_assertions_cg mat_valid_delay_cg;

	// cover different lengths of mat_valid signal
	covergroup mat_valid_length_cg with function sample(int unsigned length);
		mat_valid_length_cp: coverpoint length {
			bins short [] = {[1:5]};
			bins mid [] = {[6:20]};
			bins big [10] = {[20:70]};
			bins max [1] = {[71:$]};
		}
	endgroup

	amiq_delay_between_assertions_cg mat_request_delay_cg;
	amiq_length_cg mat_request_length_cg;

	amiq_packet_gap_cg inter_packet_gap_cg;
	amiq_packet_gap_cg intra_packet_gap_cg;
	amiq_length_cg burst_length_cg;

	// progress of transaction
	amiq_matrix_reset_stages_t progress = BEFORE_PACKET;

	// reset at different points in the transfer
	covergroup reset_after_different_stages_cg with function sample(amiq_matrix_reset_stages_t progress);
		reset_after_different_stages_cp: coverpoint progress;
	endgroup
	// number of deassertions of mat_request and mat_valid during a packet
	covergroup deassertions_during_packet_cg with function sample(int unsigned  count_req, int unsigned  count_valid);
		number_of_mat_req_deassertions_cp: coverpoint count_req {
			bins short [1] = {[1:3]};
			bins mid [1] = {[4:7]};
			bins big [2] = {[8:15]};
		}
		number_of_mat_valid_deassertions_cp: coverpoint count_valid {
			bins short [1] = {[1:3]};
			bins mid [1] = {[4:7]};
			bins big [2] = {[8:15]};
		}
	endgroup

	function new(string name = "amiq_matrix_coverage_collector", uvm_component parent);
		super.new(name, parent);

		// create the port for valid input items
		valid_ap = new("valid_ap", this);
		// create the port for invalid input items
		invalid_ap = new("invalid_ap", this);

		// create and set the names for the defined covergroups

		valid_matrix_values_cg = new();
		valid_matrix_values_cg.set_inst_name("valid_matrix_values_cg");

		invalid_matrix_values_cg = new();
		invalid_matrix_values_cg.set_inst_name("invalid_matrix_values_cg");

		mat_valid_delay_cg = new();
		mat_valid_delay_cg.set_inst_name("mat_valid_delay_cg");

		mat_valid_length_cg = new();
		mat_valid_length_cg.set_inst_name("mat_valid_length_cg");

		mat_request_delay_cg = new();
		mat_request_delay_cg.set_inst_name("mat_request_delay_cg");

		mat_request_length_cg = new();
		mat_request_length_cg.set_inst_name("mat_request_length_cg");

		inter_packet_gap_cg = new();
		inter_packet_gap_cg.set_inst_name("inter_packet_gap_cg");

		intra_packet_gap_cg = new();
		intra_packet_gap_cg.set_inst_name("intra_packet_gap_cg");

		burst_length_cg = new();
		burst_length_cg.set_inst_name("burst_length_cg");

		reset_after_different_stages_cg = new();
		reset_after_different_stages_cg.set_inst_name("reset_after_different_stages_cg");

		deassertions_during_packet_cg = new();
		deassertions_during_packet_cg.set_inst_name("deassertions_during_packet_cg");
	endfunction

	function void build_phase(uvm_phase phase);
		// get the input virtual interface from uvm_config_db
		if (!uvm_config_db# (virtual amiq_matrix_if)::get (this, "*input_agent*", "input_if", in_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")
		super.build_phase(phase);
	endfunction

	// get valid item from input monitor
	function void write_valid_ap(amiq_matrix_item received_item);

		// sample valid input values
		foreach (received_item.matrix[i])
			foreach(received_item.matrix[i][j])
				valid_matrix_values_cg.sample(received_item.matrix[i][j]);

		// sample deassertions mid packet
		deassertions_during_packet_cg.sample(count_req, count_valid);
		count_valid = 0;
		count_req = 0;
		packet_started = 0;

	endfunction

	// get invalid item
	function void write_invalid_ap(shortint bus);
		// sample invalid input values
		invalid_matrix_values_cg.sample(bus);
	endfunction

	// extra monitoring logic
	virtual task run_phase(uvm_phase phase);
		forever begin
			// handle multithreading
			fork
				reset_coverage_collector();
				begin
					// get process PID
					measure_process = process::self();
					measure();
				end
			join
		end
	endtask

	// monitor valid, request, inter, intra and burst
	virtual task measure();

		if(!has_init_reset)
			@(negedge in_vif.reset_n);
		@(posedge in_vif.reset_n);

		progress = BEFORE_PACKET;

		forever begin

			@(posedge in_vif.clock);

			// both request and valid asserted
			if (in_vif.mat_request && in_vif.mat_valid) begin

				if(!packet_started) begin
					packet_started = 1;
					progress = DURING_PACKET;
				end

				// if request only just asserted => valid waited for request => inter_packet_gap
				if ((req_duration == 0) && has_first_valid) begin
					`uvm_info(get_name(), $sformatf("inter_gap: %d", inter_gap), UVM_HIGH)
					inter_packet_gap_cg.sample(inter_gap);
					inter_gap = 0;
				end
				// if valid only just asserted => request waited for valid => intra_packet_gap
				if ((valid_duration == 0) && has_first_req) begin
					`uvm_info(get_name(), $sformatf("intra_gap: %d", intra_gap), UVM_HIGH)
					intra_packet_gap_cg.sample(intra_gap);
					intra_gap = 0;
				end

				burst_duration ++;
			end
			// burst ended
			else if (burst_duration) begin
				burst_length_cg.sample(burst_duration);
				burst_duration = 0;
			end

			// request deasserted
			if ( !in_vif.mat_request) begin

				// if request lasted for some time, after which it deasserted mid packet => request deasserted mid packet
				if(packet_started && req_duration)
					count_req++;

				if(req_duration)
					mat_request_length_cg.sample(req_duration);

				req_duration = 0;
				intra_gap = 0;
				req_delay ++;
			end
			// request asserted
			else begin

				if(!has_first_req)
					has_first_req = 1;
				else
					mat_request_delay_cg.sample(req_delay);

				req_delay = 0;
				req_duration ++;

				if(!in_vif.mat_valid)
					intra_gap ++;
			end

			// valid deasserted
			if ( !in_vif.mat_valid ) begin

				// if valid lasted for some time, after which it deasserted mid packet => valid deasserted mid packet
				if(packet_started && valid_duration)
					count_valid++;

				if(valid_duration)
					mat_valid_length_cg.sample(valid_duration);

				valid_duration = 0;
				inter_gap = 0;
				valid_delay ++;
			end
			// valid asserted
			else begin

				if(!has_first_valid)
					has_first_valid = 1;
				else
					mat_valid_delay_cg.sample(valid_delay);

				valid_delay = 0;
				valid_duration ++;

				if(!in_vif.mat_request) begin
					inter_gap ++;
					progress = DURING_BACKPRESSURE;
				end

			end

		end
	endtask


	// bring all local variables to initial state
	function void reset_local_variables();

		progress = BEFORE_PACKET;
		has_first_req = 0;
		has_first_valid = 0;
		packet_started = 0;
		count_req = 0;
		count_valid = 0;
		req_duration = 0;
		req_delay = 0;
		valid_duration = 0;
		valid_delay = 0;
		inter_gap = 0;
		intra_gap = 0;
		burst_duration = 0;

	endfunction

	// reset the coverage collector
	virtual task reset_coverage_collector();

		@(negedge in_vif.reset_n);

		if(!has_init_reset)
			has_init_reset = 1;

		reset_after_different_stages_cg.sample(progress);

		`uvm_info(get_name(), "Reseting input coverage collector", UVM_HIGH)

		// kill all other processes
		if (measure_process != null)
			measure_process.kill();

		reset_local_variables();

	endtask

endclass

`endif // AMIQ_MATRIX_COVERAGE_COLLECTOR
