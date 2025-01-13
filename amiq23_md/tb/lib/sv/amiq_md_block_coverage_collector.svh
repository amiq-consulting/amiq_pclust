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
// Creation Date    : Aug 26, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Block coverage collector. Measures information
//                    related to all items individually and collectively.
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_BLOCK_COVERAGE_COLLECTOR
`define AMIQ_MD_BLOCK_COVERAGE_COLLECTOR

// wrapper for array of covergroups workaround
class mat_element_wrapper;

	covergroup mat_element_value_cg with function sample(shortint mat_value);

		mat_element_cp: coverpoint mat_value{
			bins min[50] = {[MAT_UNDERFLOW_VALUE:-25_000]};
			bins middle[100] = {[-5_000:5_000]};
			bins max[50] = {[25_000:MAT_OVERFLOW_VALUE]};
			bins interesting_values[] = {[-2:2]};
		}
	endgroup

	function new();
		this.mat_element_value_cg = new();
	endfunction
endclass

// cover the value of intermediary products in a 3x3 matrix
covergroup det_product_value_cg with function sample(amiq_queue_of_shortint_t products_q);
	diagonal_cp: coverpoint products_q[0]{
		bins min = {DET_UNDERFLOW_VALUE};
		bins max = {DET_OVERFLOW_VALUE};
	}
	lower_triangle_cp: coverpoint products_q[1]{
		bins min = {DET_UNDERFLOW_VALUE};
		bins max = {DET_OVERFLOW_VALUE};
	}
	upper_triangle_cp: coverpoint products_q[2]{
		bins min = {DET_UNDERFLOW_VALUE};
		bins max = {DET_OVERFLOW_VALUE};
	}
	cross_cp: cross diagonal_cp, lower_triangle_cp, upper_triangle_cp;
endgroup

class amiq_md_block_coverage_collector extends uvm_component;

	// register component in UVM Factory
	`uvm_component_utils(amiq_md_block_coverage_collector)

	// declares valid items analysis port
	`uvm_analysis_imp_decl(_input_ap)
	// declares invalid items analysis port
	`uvm_analysis_imp_decl(_output_ap)

	// implements coverage collector input items analysis port as implementation port (receiving end)
	uvm_analysis_imp_input_ap #(amiq_matrix_item, amiq_md_block_coverage_collector) input_ap;
	// implements coverage collector output items analysis port as implementation port (receiving end)
	uvm_analysis_imp_output_ap #(amiq_determinant_item, amiq_md_block_coverage_collector) output_ap;

	// input monitor virtual interface
	virtual amiq_matrix_if in_vif;
	// output monitor virtual interface
	virtual amiq_determinant_if out_vif;

	// flag has first item
	bit has_first_item = 0;
	bit has_init_reset = 0;

	// count the number of back2backs
	int unsigned b2b_count = 0;

	// same item on row/column flag
	bit same_value_on_mat_row_or_column = 1;

	// variable used to track the property of a row/column of having the same value all along
	amiq_row_column_t same_row_column = NO_SAME_VALUE_ON_ROW_COLUMN;

	// variable used to track the triangular property of a matrix
	amiq_triangular_t triangular = NOT_TRIANGULAR;

	// flag to track if a matrix is upper triangular
	bit upper = 1;

	// flag to track if a matrix is lower triangular
	bit lower = 1;

	// variable used to track the permutation property of a matrix
	amiq_permutations_t permutation = NOT_PERMUTATION;

	// variable used to mark the type of b2b transfer
	amiq_type_of_b2b_t b2b_type = NOT_B2B;

	/* EXTREME B2B
	 * delay[0] == 0
	 *
	 * @WAVEDROM_START
	 {signal: [
	 {name: 'clk', wave: 'p.......'},
	 {name: 'mat_in', wave: 'x22222.2', data: ['a', 'b', 'c', 'd', 'a','b','c','d']},
	 {name: 'mat_valid', wave: '01......'},
	 {name: 'mat_request', wave: '1....01.'},
	 {name: 'det_valid', wave: '0....10.'},
	 ]}
	 @WAVEDROM_END

	 * STANDARD B2B
	 * delay[0] == 1
	 *
	 @WAVEDROM_START
	 {signal: [
	 {name: 'clk', wave: 'p.......'},
	 {name: 'mat_in', wave: 'x2222x22', data: ['a', 'b', 'c', 'd', 'a','b','c','d']},
	 {name: 'mat_valid', wave: '01...01.'},
	 {name: 'mat_request', wave: '1....01.'},
	 {name: 'det_valid', wave: '0....10.'},
	 ]}
	 @WAVEDROM_END
	 */

	// the handler of the input monitoring thread
	process input_process;

	// progress of input transaction
	amiq_input_stages_t input_progress = BEFORE_1;

	// progress of output transaction
	amiq_output_stages_t output_progress = BEFORE_VALID;

	// reset at different point in the transfer
	covergroup reset_after_different_stages_cg with function sample(amiq_input_stages_t input_progress, amiq_output_stages_t output_progress);
		reset_after_different_stages_cp: coverpoint input_progress;
		reset_when_det_valid_cp: coverpoint output_progress;
	endgroup

	// cover multiple consecutive b2b transfers
	covergroup number_of_b2b_cg with function sample(int unsigned count);
		number_of_b2b_cp: coverpoint count{
			bins b2b = {1};
			bins b2b2b = {2};
			bins b2b2b2b = {3};
			bins serial_packets [2] = {[4:10]};
		}
	endgroup

	// cover that different types of b2b transfers occured
	covergroup type_of_b2b_cg with function sample (amiq_type_of_b2b_t b2b_type);
		type_of_b2b_cp: coverpoint b2b_type;
	endgroup

	// cover individual matrix element values
	mat_element_wrapper mat_elements[];

	// variable used to compute the expected determinant of input 3x3 matrix
	longint expected_det = 0;

	// cover intermediary product values
	det_product_value_cg positive_cg;
	det_product_value_cg negative_cg;

	// value of output bus
	covergroup det_value_cg with function sample(amiq_determinant_item out_item);
		det_value_cp: coverpoint out_item.determinant{
			bins min[50] = {[DET_UNDERFLOW_VALUE:-25_000]};
			bins middle[100] = {[-5_000:5_000]};
			bins max[50] = {[25_000:DET_OVERFLOW_VALUE]};

		}
		det_value_transitions_cp: coverpoint out_item.determinant{
			bins transitions = ([DET_UNDERFLOW_VALUE:-25_000], [-5_000:5_000], [25_000:DET_OVERFLOW_VALUE] =>
				[DET_UNDERFLOW_VALUE:-25_000], [-5_000:5_000], [25_000: DET_OVERFLOW_VALUE]);
		}
		det_value_saturation_transitions_cp: coverpoint out_item.determinant{
			bins transitions = (DET_UNDERFLOW_VALUE, DET_OVERFLOW_VALUE => DET_UNDERFLOW_VALUE, DET_OVERFLOW_VALUE);
		}
	endgroup

	// cover that various matrix with special mathematical properties were sent
	covergroup interesting_matrices_cg with function sample(amiq_triangular_t triangular, amiq_permutations_t permutation);
		triangular_matrices_cp: coverpoint triangular;
		permutation_matrices_cp: coverpoint permutation;
	endgroup

	// cover that some matrices had the same value along a row/column
	covergroup same_row_or_column_matrices_cg with function sample (amiq_row_column_t row_column);
		row_column_matrices_cp: coverpoint row_column;
	endgroup

	function new(string name = "amiq_md_block_coverage_collector", uvm_component parent);
		super.new(name, parent);

		// create the port for valid input items
		input_ap = new("input_ap", this);
		// create the port for invalid input items
		output_ap = new("output_ap", this);

		// create and set the names for the defined covergroups
		reset_after_different_stages_cg = new();
		reset_after_different_stages_cg.set_inst_name("reset_after_different_stages_cg");

		mat_elements = new[`MAT_MATRIX_SIZE ** 2];
		for(int i = 0 ; i < `MAT_MATRIX_SIZE ; i++) begin
			for( int j = 0 ; j < `MAT_MATRIX_SIZE ; j++) begin
				mat_elements[(i * `MAT_MATRIX_SIZE) + j] = new();
				mat_elements[(i * `MAT_MATRIX_SIZE) + j].mat_element_value_cg.set_inst_name($sformatf("mat_element[%d][%d]_value_cg", i, j));
			end
		end

		det_value_cg = new();
		det_value_cg.set_inst_name("det_value_cg");

		// every factorial > 2 is an even number, so half the products are summed and half are subtracted

		positive_cg = new();
		positive_cg.set_inst_name("positive_det_products_value_cg");

		negative_cg = new();
		negative_cg.set_inst_name("negative_det_products_value_cg");

		number_of_b2b_cg = new();
		number_of_b2b_cg.set_inst_name("number_of_b2b_cg");

		type_of_b2b_cg = new();
		type_of_b2b_cg.set_inst_name("type_of_b2b_cg");

		interesting_matrices_cg = new();
		interesting_matrices_cg.set_inst_name("interesting_matrices_cg");

		same_row_or_column_matrices_cg = new();
		same_row_or_column_matrices_cg.set_inst_name("same_row_or_column_matrices_cg");

	endfunction

	function void build_phase(uvm_phase phase);
		// get the input virtual interface from uvm_config_db
		if (!uvm_config_db# (virtual amiq_matrix_if)::get (this, "*input_agent*", "input_if", in_vif))
			`uvm_fatal(get_name(), "Could not get the input virtual interface handle.")
		// get the output virtual interface from uvm_config_db
		if (!uvm_config_db# (virtual amiq_determinant_if)::get (this, "*output_agent*", "output_if", out_vif))
			`uvm_fatal(get_name(), "Could not get the output virtual interface handle.")
		super.build_phase(phase);
	endfunction

	/**
	 * compute all the intermediate products of a input item ( 3x3 matrix)
	 * @param received_item - input item
	 */

	function void compute_and_sample_intermediate_products(amiq_matrix_item received_item);

		// queue of shortints to store intermediate products
		// in order: aei, dhc, bfg, gec, hfa, dbi
		amiq_queue_of_shortint_t positive_porducts_q;
		amiq_queue_of_shortint_t negative_products_q;

		positive_porducts_q.push_back(received_item.matrix[0][0] * received_item.matrix[1][1] * received_item.matrix[2][2]);
		positive_porducts_q.push_back(received_item.matrix[1][0] * received_item.matrix[2][1] * received_item.matrix[0][2]);
		positive_porducts_q.push_back(received_item.matrix[0][1] * received_item.matrix[1][2] * received_item.matrix[2][0]);

		positive_cg.sample(positive_porducts_q);

		negative_products_q.push_back(received_item.matrix[0][2] * received_item.matrix[1][1] * received_item.matrix[2][0]);
		negative_products_q.push_back(received_item.matrix[1][2] * received_item.matrix[2][1] * received_item.matrix[0][0]);
		negative_products_q.push_back(received_item.matrix[1][0] * received_item.matrix[0][1] * received_item.matrix[2][2]);

		negative_cg.sample(negative_products_q);

		// 6 intermediary products => (sqrt(9))! => 3! => 6 products
		// aei + dhc + bfg - gec - hfa - dbi
		expected_det = 0;
		for( int i = 0 ; i < (factorial($sqrt(`DET_MATRIX_SIZE)) / 2); i++) begin
			expected_det += positive_porducts_q[i];
			expected_det -= negative_products_q[i];
		end

		positive_porducts_q.delete();
		negative_products_q.delete();

	endfunction


	// get input item
	function void write_input_ap(amiq_matrix_item received_item);
		// sample products
		compute_and_sample_intermediate_products(received_item);
		// if the result is saturated, transaction is in overflow state
		if ( (expected_det > DET_OVERFLOW_VALUE) || (expected_det < DET_UNDERFLOW_VALUE))
			output_progress = DURING_OVERFLOW;

		// sample individual elements
		for( int i = 0 ; i < `MAT_MATRIX_SIZE ; i++)
			for( int j = 0 ; j < `MAT_MATRIX_SIZE ; j++)
				mat_elements[(i * `MAT_MATRIX_SIZE) + j].mat_element_value_cg.sample(received_item.matrix[i][j]);
		// sample interesting matrices
		triangular = NOT_TRIANGULAR;
		permutation = NOT_PERMUTATION;
		same_row_column = NO_SAME_VALUE_ON_ROW_COLUMN;
		upper = 1;
		lower = 1;

		// determine if matrix is triangular
		// upper
		// a b c
		// 0 e f
		// 0 0 i
		for ( int i = 0 ; i < `MAT_MATRIX_SIZE ; i++)
			for (int j = 0 ; j < i ; j++)
				if(received_item.matrix[i][j])
					upper = 0;
		// lower
		// a 0 0
		// d e 0
		// g h i
		for ( int i = 0 ; i < `MAT_MATRIX_SIZE ; i++)
			for (int j = i + 1; j < `MAT_MATRIX_SIZE ; j++)
				if(received_item.matrix[i][j])
					lower = 0;
		if (upper)
			triangular = UPPER;
		else if (lower)
			triangular = LOWER;

		// determine if matrix is permutation
		//
		// IDENTITY    PERMUTATIONS: 3! = 6 in total
		// 1 0 0       1 0 0    0 1 0    0 1 0    0 0 1    0 0 1
		// 0 1 0       0 0 1    1 0 0    0 0 1    1 0 0    0 1 0
		// 0 0 1       0 1 0    0 0 1    1 0 0    0 1 0    1 0 0
		if ((received_item.matrix[0][0] == 1) && (received_item.matrix[0][1] == 0) && (received_item.matrix[0][2] == 0))begin
			if ((received_item.matrix[1][0] == 0) && (received_item.matrix[1][1] == 1) && (received_item.matrix[1][2] == 0)) begin
				if ((received_item.matrix[2][0] == 0) && (received_item.matrix[2][1] == 0) && (received_item.matrix[2][2] == 1)) begin
					permutation = IDENTITY;
				end
			end
			else if ((received_item.matrix[1][0] == 0) && (received_item.matrix[1][1] == 0) && (received_item.matrix[1][2] == 1)) begin
				if ((received_item.matrix[2][0] == 0) && (received_item.matrix[2][1] == 1) && (received_item.matrix[2][2] == 0)) begin
					permutation = PERMUTATIONS;
				end
			end
		end
		else if ((received_item.matrix[0][0] == 0) && (received_item.matrix[0][1] == 1) && (received_item.matrix[0][2] == 0)) begin
			if ((received_item.matrix[1][0] == 1) && (received_item.matrix[1][1] == 0) && (received_item.matrix[1][2] == 0)) begin
				if ((received_item.matrix[2][0] == 0) && (received_item.matrix[2][1] == 0) && (received_item.matrix[2][2] == 1)) begin
					permutation = PERMUTATIONS;
				end
			end
			else if ((received_item.matrix[1][0] == 0) && (received_item.matrix[1][1] == 0) && (received_item.matrix[1][2] == 1)) begin
				if ((received_item.matrix[2][0] == 1) && (received_item.matrix[2][1] == 0) && (received_item.matrix[2][2] == 0)) begin
					permutation = PERMUTATIONS;
				end
			end
		end
		else if ((received_item.matrix[0][0] == 0) && (received_item.matrix[0][1] == 0) && (received_item.matrix[0][2] == 1)) begin
			if ((received_item.matrix[1][0] == 1) && (received_item.matrix[1][1] == 0) && (received_item.matrix[1][2] == 0)) begin
				if ((received_item.matrix[2][0] == 0) && (received_item.matrix[2][1] == 1) && (received_item.matrix[2][2] == 0)) begin
					permutation = PERMUTATIONS;
				end
			end
			else if ((received_item.matrix[1][0] == 0) && (received_item.matrix[1][1] == 1) && (received_item.matrix[1][2] == 0)) begin
				if ((received_item.matrix[2][0] == 1) && (received_item.matrix[2][1] == 0) && (received_item.matrix[2][2] == 0)) begin
					permutation = PERMUTATIONS;
				end
			end
		end
		interesting_matrices_cg.sample(triangular, permutation);

		// same values on row / column
		for (int i = 0 ; i < `MAT_MATRIX_SIZE; i++) begin

			// same value on a row case
			same_value_on_mat_row_or_column = 1;
			for (int j = 0 ; j < (`MAT_MATRIX_SIZE - 1); j++) begin
				if (received_item.matrix[i][j] != received_item.matrix[i][j + 1])
					same_value_on_mat_row_or_column = 0;
			end

			if (same_value_on_mat_row_or_column) begin
				if (received_item.matrix[i][0] == -1)
					same_row_column = MINUS_ONE;
				else if (received_item.matrix[i][0] == 0)
					same_row_column = ZERO;
				else if (received_item.matrix[i][0] == 1)
					same_row_column = ONE;
				else
					same_row_column = OTHER;
			end

			same_row_or_column_matrices_cg.sample(same_row_column);

			// sample value on a column case
			same_value_on_mat_row_or_column = 1;
			for (int j = 0 ; j < (`MAT_MATRIX_SIZE - 1); j++) begin
				// treat array as matrix
				if (received_item.matrix[j][i] != received_item.matrix[j + 1][i])
					same_value_on_mat_row_or_column = 0;
			end
			if (same_value_on_mat_row_or_column) begin
				if (received_item.matrix[0][i] == -1)
					same_row_column = MINUS_ONE;
				else if (received_item.matrix[0][i] == 0)
					same_row_column = ZERO;
				else if (received_item.matrix[0][i] == 1)
					same_row_column = ONE;
				else
					same_row_column = OTHER;
			end
			same_row_or_column_matrices_cg.sample(same_row_column);
		end

		// after first item
		if (has_first_item) begin

			if (received_item.pre_element_delay[0][0] > 1) begin
				b2b_count = 0;
				b2b_type = NOT_B2B;
			end

			else begin
				b2b_count ++;
				if (received_item.pre_element_delay[0][0] == 1)
					b2b_type = STANDARD_B2B;
				else
					b2b_type = EXTREME_B2B;
			end

			type_of_b2b_cg.sample (b2b_type);
			number_of_b2b_cg.sample(b2b_count);

		end
		else
			has_first_item = 1;
	endfunction

	// get output item
	function void write_output_ap(amiq_determinant_item received_item);
		// output transaction finished
		det_value_cg.sample(received_item);
	endfunction

	virtual task run_phase(uvm_phase phase);
		forever begin
			fork
				reset_coverage_collector();
				begin
					input_process = process::self();
					monitor_input();
				end
			join
		end
	endtask

	// monitor mat_request information thread
	virtual task monitor_input();

		if(!has_init_reset)
			@(negedge in_vif.reset_n);
		@(posedge in_vif.reset_n);

		forever begin

			input_progress = BEFORE_1;
			output_progress = BEFORE_VALID;

			for (int i = 0 ; i < (`MAT_MATRIX_SIZE ** 2) ; i++) begin
				@(posedge in_vif.clock);
				while(!in_vif.mat_valid)
					@(posedge in_vif.clock);
				input_progress++; /* @DVT_LINTER_WAIVER "Generated Code Waiver" DISABLE SVTB.5.14 */
			end
			// output transaction is now ongoing
			output_progress = DURING_VALID;
			@(posedge in_vif.mat_request);
		end
	endtask

	// bring all local variables to initial state
	function void reset_local_variables();
		// reset local variables
		input_progress = BEFORE_1;
		output_progress = BEFORE_VALID;
		same_row_column = NO_SAME_VALUE_ON_ROW_COLUMN;
		permutation = NOT_PERMUTATION;
		triangular = NOT_TRIANGULAR;
		b2b_count = 0;
		has_first_item = 0;
	endfunction

	// reset the coverage collector
	task reset_coverage_collector();

		@(negedge in_vif.reset_n);

		if( !has_init_reset)
			has_init_reset = 1;

		reset_after_different_stages_cg.sample(input_progress, output_progress);

		// kill all other processes

		if (input_process != null)
			input_process.kill();

		reset_local_variables();
	endtask

endclass

`endif // AMIQ_MD_BLOCK_COVERAGE_COLLECTOR
