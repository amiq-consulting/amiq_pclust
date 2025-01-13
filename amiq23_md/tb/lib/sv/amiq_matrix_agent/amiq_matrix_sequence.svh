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
// Description      : Input sequence. Controls the physical transactions.
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_SEQUENCE
`define AMIQ_MATRIX_SEQUENCE

class amiq_matrix_sequence extends uvm_sequence#(amiq_matrix_item);

	// register this object in the UVM Factory
	`uvm_object_utils(amiq_matrix_sequence)

	// declare pointer to input sequencer
	`uvm_declare_p_sequencer(amiq_matrix_sequencer)

	// randomized item
	rand amiq_matrix_item mat_item;

	// minimum and maximum values for every mat elements
	rand bit signed [`MAT_BUS_WIDTH - 1:0] min_value ;
	rand bit signed [`MAT_BUS_WIDTH - 1:0] max_value ;

	// minimum and maximum values for every delay
	rand int unsigned min_delay;
	rand int unsigned max_delay;

	// flag that only allows 1s and 0s in a matrix
	rand bit permutations;

	// flag that only allows saturated values in a matrix
	rand bit saturation;

	// default values for item fields
	constraint matrix_seq_c{

		soft permutations dist { 0:= 95, 1:= 5};
		soft saturation dist { 0:= 95, 1:= 5};

		soft min_delay == 0;
		soft max_delay == `MAT_DELAY_MAX_VALUE ;

		if(!permutations && !saturation) {
			// 32 ^ 3 = 2 ^ 15 = 32768 = OVERFLOW_VALUE
			soft min_value dist { -32 := 95, MAT_UNDERFLOW_VALUE := 5};
			soft max_value dist {  32 := 95, MAT_OVERFLOW_VALUE  := 5};
		} else if (permutations) {
			soft min_value == 0;
			soft max_value == 1;
		}

		foreach (mat_item.pre_element_delay[i])
			foreach (mat_item.pre_element_delay[i][j])
				soft mat_item.pre_element_delay[i][j] inside {[min_delay:max_delay]};

		foreach (mat_item.matrix[i])
			foreach (mat_item.matrix[i][j]) {
				if(!saturation)
					soft mat_item.matrix[i][j] inside {[min_value:max_value]};
				else
					soft mat_item.matrix[i][j] dist {MAT_UNDERFLOW_VALUE := 1, MAT_OVERFLOW_VALUE := 1};
			}
	}

	function new(string name = "amiq_matrix_sequence");
		super.new(name);

		mat_item = amiq_matrix_item::type_id::create("mat_item");

	endfunction

	virtual task body();

		// send randomized mat_item
		`uvm_send(mat_item)

	endtask

endclass

`endif // AMIQ_MATRIX_SEQUENCE
