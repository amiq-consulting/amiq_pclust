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
// Description      : The input interface of the block, used for
//                  driving the matrix elements
//----------------------------------------------------------------------------

`ifndef AMIQ_MATRIX_IF
`define AMIQ_MATRIX_IF

`include "amiq_matrix_defines.svh"

interface amiq_matrix_if(
		// syncronization signal
		input logic clock,
		// bring to initial state signal
		input logic reset_n
	);
	// Used to validate the mat_in signal, otherwise the value is ignored
	logic mat_valid;
	// Used to indicate if the DUT requires more matrix elements
	logic mat_request;
	// Used to drive the elements of the matrix
	logic [`MAT_BUS_WIDTH - 1:0] mat_in;

	bit has_init_reset = 0;
	bit has_checks = 1;

	initial begin
		//skip the posedge of reset at time 0
		@(negedge reset_n);
		@(posedge reset_n);
		has_init_reset <= 1;
	end

	// signal should not be unkown after first reset
	property signal_not_unkown_PROPERTY(logic signal);
		@(posedge clock)
			disable iff(!has_init_reset || !has_checks)
			(!$isunknown(signal));
	endproperty

	AMIQ_MD_MAT_VALID_NOT_UNKOWN_CHECK : assert property (signal_not_unkown_PROPERTY(mat_valid)) else
		$error("mat_valid is unkown %m");

	AMIQ_MD_MAT_REQUEST_NOT_UNKOWN_CHECK : assert property (signal_not_unkown_PROPERTY(mat_request)) else
		$error("mat_request is unkown %m");

	// validated mat_in should not be unkown after first reset
	property mat_in_not_unkown_when_valid_PROPERTY;
		@(posedge clock)
			disable iff(!has_init_reset || !has_checks)
			mat_valid |-> (!$isunknown(mat_in));
	endproperty

	AMIQ_MD_IN_NOT_UNKOWN_WHEN_VALID_CHECK : assert property (mat_in_not_unkown_when_valid_PROPERTY) else
		$error("valid mat_in is unkown %m");

	// mat_request should be 1 after reset
	property mat_request_after_reset_PROPERTY;
		@(posedge clock)
			disable iff(!has_checks || !has_init_reset)
			$rose(reset_n) |-> mat_request === 1;
	endproperty

	AMIQ_MD_IN_MAT_REQUEST_AFTER_RESET_CHECK : assert property (mat_request_after_reset_PROPERTY) else
		$error("mat_request value after reset is not correct %m");

	// mat_valid should be kept asserted until request comes
	property data_stable_until_request_PROPERTY(logic signal);
		@(posedge clock)
			disable iff(!has_init_reset || !has_checks || !reset_n)
			mat_valid && !mat_request |=> $stable(signal)[*1:$] ##1 mat_request;
	endproperty

	AMIQ_MD_MAT_VALID_UNTIL_MAT_REQUEST_CHECK : assert property (data_stable_until_request_PROPERTY(mat_valid)) else
		$error("mat_valid is not asserted until request is asserted %m");

	AMIQ_MD_IN_STABLE_UNTIL_REQUEST_CHECK : assert property (data_stable_until_request_PROPERTY(mat_in)) else
		$error("mat_in is not stable until request is asserted %m");

endinterface

`endif // AMIQ_MATRIX_IF

