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
// Description      : Top module
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_TB_TOP
`define AMIQ_MD_TB_TOP

module amiq_md_tb_top;

	import uvm_pkg::*;
	import amiq_md_test_pkg::*;

	// clk and reset interface
	amiq_clock_and_reset_if clk_rst_if();

	// input interface
	amiq_matrix_if input_if(
		.clock(clk_rst_if.clock),
		.reset_n(clk_rst_if.reset_n)
	);

	// output interface
	amiq_determinant_if output_if(
		.clock(clk_rst_if.clock),
		.reset_n(clk_rst_if.reset_n)
	);

	// checking interface
	amiq_md_sva_if sva_if(
		.clock(clk_rst_if.clock),
		.reset_n(clk_rst_if.reset_n)
	);

	// the rtl
	amiq_md dut(
		.clk(clk_rst_if.clock),
		.rst_n(clk_rst_if.reset_n),
		.mat_valid(input_if.mat_valid),
		.mat_request(input_if.mat_request),
		.mat_in(input_if.mat_in),
		.det(output_if.det),
		.det_valid(output_if.det_valid),
		.overflow(output_if.overflow)
	);

	initial begin
		// register interfaces in the uvm configuration database
		uvm_config_db #(virtual amiq_matrix_if)::set(null,  "*input_agent*", "input_if",   input_if);
		uvm_config_db #(virtual amiq_determinant_if)::set(null, "*output_agent*", "output_if", output_if);
		uvm_config_db #(virtual amiq_clock_and_reset_if)::set(null, "*clk_rst_agent*", "clk_rst_if", clk_rst_if);
		uvm_config_db #(virtual amiq_md_sva_if)::set(null, "*env*", "sva_if", sva_if);

		// run the test specified in the command
		run_test();
	end

endmodule

`endif // AMIQ_MD_TB_TOP
