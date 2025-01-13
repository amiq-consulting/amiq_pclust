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
// Description      : Input item. Abstractization of information
//                    from the input interface signals.
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_ITEM
`define AMIQ_MATRIX_ITEM

class amiq_matrix_item extends uvm_sequence_item;

	// the matrix displayed as a vector
	rand bit signed [`MAT_BUS_WIDTH - 1:0] matrix[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE];

	// delay between elements, array of bytes
	// delay[0] refers to delay between packets (pre packet delay)
	// delay[0] measures the delay from the last packet, not from output
	rand int pre_element_delay[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE];

	// register this object in the UVM Factory
	`uvm_object_utils_begin(amiq_matrix_item)
		foreach(matrix[i])
			`uvm_field_sarray_int(matrix[i], UVM_ALL_ON)
			foreach(pre_element_delay[i])
				`uvm_field_sarray_int(pre_element_delay[i], UVM_ALL_ON + UVM_NOCOMPARE + UVM_UNSIGNED)
	`uvm_object_utils_end

	// default values for delays
	constraint delay_value_c {
		foreach (pre_element_delay[i])
			foreach (pre_element_delay[i][j])
				soft pre_element_delay[i][j] inside {[0:1000]};
	}

	function new(string name = "amiq_md_input_item");
		super.new(name);
	endfunction

	// Function to convert item to string
	function string convert2string();
		string content = "";
		for( int i = 0 ; i < `MAT_MATRIX_SIZE ; i++) begin
			for( int j = 0 ; j < `MAT_MATRIX_SIZE ; j++) begin
				$sformat(content, "%s pre_delay[%d][%d]: %d", content, i, j, pre_element_delay[i][j]);
				$sformat(content, "%s matrix[%d][%d]: %h", content, i, j, matrix[i][j]);
			end
		end
		return content;
	endfunction

	/**
	 * Function that gets the cofactor of mat[p][q] in temp[][]
	 * @param mat - starting matrix
	 * @param temp - temporary variable that stores the cofactor
	 * @param p - current element row
	 * @param q - current element column
	 * @param n - current matrix size
	 */
	function void get_cofactor(bit signed [`MAT_BUS_WIDTH - 1:0] mat[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE],
			int p, int q, int n,
			ref bit signed [`MAT_BUS_WIDTH - 1:0] temp[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE]
		);

		int i = 0;
		int j = 0;

		// Looping for each element of
		// the matrix
		for (int row = 0; row < n; row++) begin
			for (int col = 0; col < n; col++) begin

				// Copying into temporary matrix only those element which are
				// not in given row and column
				if ((row != p) && (col != q)) begin
					temp[i][j++] = mat[row][col];

					// Row is filled, so increase row
					// index and reset col index
					if (j == (n - 1)) begin
						j = 0;
						i++;
					end
				end
			end
		end
	endfunction

	/**
	 * Recursive function for finding
	 * determinant of matrix.
	 *
	 * Credits: https://www.geeksforgeeks.org/cpp-program-for-determinant-of-a-matrix/
	 * @param mat - matrix to be computed
	 * @param n - current size of matrix
	 * @return
	 */
	function automatic longint determinant_of_matrix(bit signed [`MAT_BUS_WIDTH - 1:0] mat[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE], int n);

		// To store cofactors
		bit signed [`MAT_BUS_WIDTH - 1:0] temp[`MAT_MATRIX_SIZE][`MAT_MATRIX_SIZE];

		// To store sign multiplier
		int sign = 1;

		// Initialize result
		determinant_of_matrix = 0;

		//  Base case : if matrix contains
		// single element
		if (n == 1)
			return mat[0][0];

		// Iterate for each element of
		// first row
		for (int f = 0; f < n; f++) begin

			// Getting Cofactor of mat[0][f]
			get_cofactor(mat,  0, f, n, temp);
			determinant_of_matrix += sign * mat[0][f] * determinant_of_matrix(temp, n - 1);

			// terms are to be added with alternate sign
			sign = -sign;
		end

	endfunction

endclass

`endif // AMIQ_MATRIX_ITEM
