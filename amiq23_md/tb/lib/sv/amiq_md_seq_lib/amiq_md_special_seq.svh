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

`ifndef AMIQ_MD_SPECIAL_SEQ
`define AMIQ_MD_SPECIAL_SEQ

class amiq_md_special_seq extends amiq_ectb_sequence;

	`uvm_object_utils(amiq_md_special_seq)
	`uvm_declare_p_sequencer(amiq_md_virtual_sequencer)

	// the physical clock and reset sequence
	amiq_clock_and_reset_sequence clk_rst_sequence;

	string reset_pkt_nr_constraints;
	string matrix_pkt_nr_constraints;
	string exact_value_constraints;
	string delay_pattern_constraints;
	string flags[$];

	// clock period
	bit unsigned [7:0] period = 20;

	// variables used to convert constraints
	rand bit signed [`MAT_BUS_WIDTH - 1:0] matrix_model[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE];
	rand bit unsigned [8 - 1:0] delay_model[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE];

	static int mat_item_cnt;

	function new(string name = "amiq_md_special_seq");
		super.new(name);

	endfunction

	virtual task body();
		int num_resets, num_input;
		`include "seq_1_svas.svh"
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

		reset_pkt_nr_constraints = string_reg("param_A", "val_0");
		flags.push_back(reset_pkt_nr_constraints);
		matrix_pkt_nr_constraints = string_reg("param_B","val_0");
		flags.push_back(matrix_pkt_nr_constraints);
		exact_value_constraints = string_reg("param_E","val_4");
		flags.push_back(exact_value_constraints);
		delay_pattern_constraints = string_reg("param_F","val_3");
		flags.push_back(delay_pattern_constraints);

	endfunction : register_all_vars

	task drive_matrix();
		amiq_matrix_item mat_item;

		mat_item = amiq_matrix_item::type_id::create($sformatf("mat_item%0d", mat_item_cnt));

		case (exact_value_constraints)
			"val_0": begin
				foreach (matrix_model[i])
					foreach (matrix_model[i][j])
						matrix_model[i][j] = 0;
			end // zero
			"val_1": begin
				foreach (matrix_model[i])
					foreach (matrix_model[i][j])
						matrix_model[i][j] = 1;
			end // one
			"val_2": begin
				foreach (matrix_model[i])
					foreach (matrix_model[i][j])
						matrix_model[i][j] = -1;
			end // minus_one
			"val_3": begin
				foreach (matrix_model[i])
					foreach (matrix_model[i][j])
						matrix_model[i][j] = 0;
				matrix_model[0][0] = 7;
				matrix_model[1][1] = 31;
				matrix_model[2][2] = 151;
			end // almost_ovf
			"val_4": begin
				if(!randomize(matrix_model))
					`uvm_fatal(get_name(),"Couldn't randomize matrix model")
			end // random
		endcase

		case (delay_pattern_constraints)
			"val_0": begin
				foreach (delay_model[i])
					foreach (delay_model[i][j])
						if(i*`MAT_MATRIX_SIZE + j % 2 == 0)
							delay_model[i][j] = 1;
						else
							delay_model[i][j] = 2;
			end // 1-2
			"val_1": begin
				foreach (delay_model[i])
					foreach (delay_model[i][j])
						if(i*`MAT_MATRIX_SIZE + j % 2 == 0)
							delay_model[i][j] = 5;
						else
							delay_model[i][j] = 10;
			end // 5-10
			"val_2": begin
				foreach (delay_model[i])
					foreach (delay_model[i][j])
						if(i*`MAT_MATRIX_SIZE + j % 2 == 0)
							delay_model[i][j] = 10;
						else
							delay_model[i][j] = 15;
			end // 10-15
			"val_3": begin
				if(!randomize(delay_model))
					`uvm_fatal(get_name(),"Couldn't randomize delay model")
			end // random
		endcase

		`uvm_do_on_with(mat_item, p_sequencer.in_sequencer, {
				foreach(mat_item.matrix[i])
					foreach(mat_item.matrix[i][j]){
						mat_item.matrix[i][j] == matrix_model[i][j];
						mat_item.pre_element_delay[i][j] == delay_model[i][j];
					}
			})
		mat_item_cnt++;
	endtask

endclass

`endif // AMIQ_MD_SPECIAL_SEQ
