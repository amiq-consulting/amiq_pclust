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
// Creation Date    : Aug 1, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Base virtual sequence
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_BASE_SEQ
`define AMIQ_MD_BASE_SEQ

class amiq_md_base_seq extends amiq_ectb_sequence;

	`uvm_object_utils(amiq_md_base_seq)
	`uvm_declare_p_sequencer(amiq_md_virtual_sequencer)

	// the physical clock and reset sequence
	amiq_clock_and_reset_sequence clk_rst_sequence;
	string reset_pkt_nr_constraints;
	string matrix_pkt_nr_constraints;
	string delay_type_constraints;
	string interesting_matrix_constraints;
	string flags[$];

	// clock period
	bit unsigned [7:0] period = 20;

	// variables used to convert constraints
	int delay_element;
	rand int max_element;
	rand int min_element;

	static int mat_item_cnt;

	function new(string name = "amiq_md_base_seq");
		super.new(name);

	endfunction

	virtual task body();
		int num_resets, num_input;
		`include "seq_0_svas.svh"
		case (reset_pkt_nr_constraints)
			"val_0": num_resets = 1; // initial
			"val_1": num_resets = 10; // small
			"val_2": num_resets = 100; // large
		endcase
		case (matrix_pkt_nr_constraints)
			"val_0": num_input = 1000; // small
			"val_1": num_input = 5000; // medium
			"val_2": num_input = 10000; //large
		endcase
		fork
			// randomize and create clock and reset sequences
			repeat (num_resets) begin
				`uvm_do_on(clk_rst_sequence, p_sequencer.clk_rst_sequencer)
			end

			// randomize and create input sequences
			repeat (num_input) begin
				drive_matrix();
			end
		join

	endtask

	virtual function void register_all_vars();
		super.register_all_vars();

		reset_pkt_nr_constraints = string_reg("param_A","val_0");
		flags.push_back(reset_pkt_nr_constraints);
		matrix_pkt_nr_constraints = string_reg("param_B","val_0");
		flags.push_back(matrix_pkt_nr_constraints);
		delay_type_constraints = string_reg("param_C","val_2");
		flags.push_back(delay_type_constraints);
		interesting_matrix_constraints = string_reg("param_D","val_0");
		flags.push_back(interesting_matrix_constraints);

	endfunction : register_all_vars

	task drive_matrix();
		amiq_matrix_item mat_item;

		mat_item = amiq_matrix_item::type_id::create($sformatf("mat_item%0d", mat_item_cnt));

		case (delay_type_constraints)
			"val_0": delay_element = 0; // b2b
			"val_1": delay_element = 10; // small
			"val_2": delay_element = 100; // medium
			"val_3": delay_element = 255; // large
		endcase

		case (interesting_matrix_constraints)
			"val_0": begin
				if(!randomize(max_element) with {
							max_element dist{ 32 := 95, MAT_OVERFLOW_VALUE := 5};
						})
					`uvm_fatal(get_name(),"Couldn't randomize max mat element")
				if(!randomize(min_element) with {
							min_element dist{ -32 := 95, MAT_UNDERFLOW_VALUE := 5};
						})
					`uvm_fatal(get_name(),"Couldn't randomize min mat element")
			end // no
			"val_1": begin
				max_element = 1;
				min_element = 0;
			end // permutation
			"val_2": begin
				max_element = MAT_OVERFLOW_VALUE;
				min_element = MAT_OVERFLOW_VALUE;
			end // saturation
		endcase

		`uvm_do_on_with(mat_item, p_sequencer.in_sequencer, {
				foreach(mat_item.matrix[i])
					foreach(mat_item.matrix[i][j]){
						mat_item.matrix[i][j] inside {[min_element:max_element]};
						mat_item.pre_element_delay[i][j] == delay_element;
					}
			})

		mat_item_cnt++;
	endtask

endclass

`endif // AMIQ_MD_BASE_SEQ