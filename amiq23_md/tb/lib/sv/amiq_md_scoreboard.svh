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
// Creation Date    : Aug 8, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Scoreboard used to compare expected items to collected items
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_SCOREBOARD
`define AMIQ_MD_SCOREBOARD

class amiq_md_scoreboard extends uvm_scoreboard;

	// register component in the UVM Factory
	`uvm_component_utils(amiq_md_scoreboard)

	// declares expected items analysis port
	`uvm_analysis_imp_decl(_expected_port)
	// declares collected items analysis port
	`uvm_analysis_imp_decl(_collected_port)
	// declares reset items analysis port
	`uvm_analysis_imp_decl(_reset_port)

	// this port is used to collect data from input bus and compute expected data at the output
	uvm_analysis_imp_expected_port  #(amiq_matrix_item,  amiq_md_scoreboard) expected_port;
	// this port is used to collect data from the output bus
	uvm_analysis_imp_collected_port #(amiq_determinant_item, amiq_md_scoreboard) collected_port;
	// this port is used to collect the reset information
	uvm_analysis_imp_reset_port #(amiq_clock_and_reset_item, amiq_md_scoreboard) reset_port;

	// array of the expected items on the output
	amiq_determinant_item expected_item_q[$];

	// variable used for saturation comparison in write expected
	longint det = 0;

	// variable used for computing expected delay
	int unsigned del = 0;

	function new(string name = "amiq_md_scoreboard", uvm_component parent);
		super.new(name, parent);
		// create the expected port
		expected_port  = new("expected_port",  this);
		// create the collected port
		collected_port = new("collected_port", this);
		// create the reset port
		reset_port = new("reset_port", this);
	endfunction

	// transform input data into expected data
	function void write_expected_port(amiq_matrix_item received_item);

		// Compute expected items
		amiq_determinant_item expected_item;
		expected_item = amiq_determinant_item::type_id::create("expected_item");

		`uvm_info(get_name(), $sformatf("RECEIVED: %s", received_item.convert2string()), UVM_HIGH)

		det = received_item.determinant_of_matrix(received_item.matrix, `MAT_MATRIX_SIZE);

		// if needed, saturate the result, and mark overflow
		if (det < DET_UNDERFLOW_VALUE) begin
			expected_item.determinant = DET_UNDERFLOW_VALUE;
			expected_item.overflow = 1;
		end
		// positive saturation
		else if (det > DET_OVERFLOW_VALUE) begin
			expected_item.determinant = DET_OVERFLOW_VALUE;
			expected_item.overflow = 1;
		end
		// negative saturation
		else begin
			expected_item.determinant = det[`DET_BUS_WIDTH-1:0];
			expected_item.overflow = 0;
		end

		del = 0;
		// compute expected delay
		for ( int i = 0 ; i < `MAT_MATRIX_SIZE ; i++)
			for (int j = 0 ; j < `MAT_MATRIX_SIZE ; j++)
				del += received_item.pre_element_delay[i][j];

		//every valid and requested matrix element is 1 clock cycle
		expected_item.pre_det_delay = del + (`MAT_MATRIX_SIZE ** 2);
		expected_item_q.push_back(expected_item);

	endfunction

	// collect output data and compare with expected
	function void write_collected_port(amiq_determinant_item received_item);

		amiq_determinant_item expected_item;

		AMIQ_MD_UNEXPECTED_OUT_CHECK :assert (expected_item_q.size() != 0) else
			`uvm_error(get_name(), "Unexpected output")

		expected_item = expected_item_q.pop_front();

		`uvm_info(get_name(), $sformatf("EXPECTED: %s", expected_item.convert2string()), UVM_HIGH)
		`uvm_info(get_name(), $sformatf("COLLECTED: %s", received_item.convert2string()), UVM_HIGH)

		AMIQ_MD_DATA_MISMATCH_CHECK :assert (expected_item.compare(received_item)) else
			`uvm_error(get_name(), $sformatf("Data has not matched, expected: %s collected: %s", expected_item.convert2string(), received_item.convert2string()))

		AMIQ_MD_RESULT_NEXT_CYCLE_CHECK :assert (expected_item.pre_det_delay == received_item.pre_det_delay) else
			`uvm_error(get_name(), $sformatf("Data has not arrived as expected, expected: %s collected: %s", expected_item.convert2string(), received_item.convert2string()))

	endfunction

	// handle reset in scoreboard
	function void write_reset_port(amiq_clock_and_reset_item received_item);
		// Reset queues
		if (received_item.length > 0) begin
			expected_item_q.delete();
			det = 0;
			del = 0;
		end
	endfunction

	function void check_phase(uvm_phase phase);
		super.check_phase(phase);

		// check at the end of test that queues are empty
		AMIQ_MD_EMPTY_QUEUES_CHECK : assert (expected_item_q.size() == 0) else
			`uvm_error(get_name(), "The expected item queue was not empty at the end of simulation.")

	endfunction

endclass

`endif // AMIQ_MD_SCOREBOARD
