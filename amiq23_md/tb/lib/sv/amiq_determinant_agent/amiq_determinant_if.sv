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
// Description      : The output interface of the block
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_IF
`define AMIQ_DETERMINANT_IF

`include "amiq_determinant_defines.svh"

interface amiq_determinant_if(
		// syncronization signal
		input clock,
		// bring to initial state signal
		input reset_n
	);
	// Used to indicate if the output data is valid
	logic det_valid;
	// Used to indicate if an overflow occurred
	logic overflow;
	// Used to drive the determinant of the matrix
	logic [`DET_BUS_WIDTH - 1:0] det;

	bit has_init_reset = 0;
	bit has_checks = 1;

	initial begin
		// skip the posedge of reset at time 0
		@(negedge reset_n);
		@(posedge reset_n);
		has_init_reset <= 1;
	end

	// det_valid should not be unkown after first reset
	property signal_not_unkown_PROPERTY(logic signal);
		@(posedge clock)
			disable iff(!has_init_reset || !has_checks)
			(!$isunknown(signal));
	endproperty

	AMIQ_MD_DET_VALID_NOT_UNKOWN_CHECK : assert property (signal_not_unkown_PROPERTY(det_valid)) else
		$error("det_valid is unkown %m");

	AMIQ_MD_OVERFLOW_NOT_UNKOWN_CHECK : assert property (signal_not_unkown_PROPERTY(overflow)) else
		$error("overflow is unkown %m");

	// validated det should not be unkown after first reset
	property det_not_unkown_when_valid_PROPERTY;
		@(posedge clock)
			disable iff(!has_init_reset || !has_checks)
			det_valid |-> (!$isunknown(det));
	endproperty

	AMIQ_MD_DET_NOT_UNKOWN_WHEN_VALID_CHECK : assert property (det_not_unkown_when_valid_PROPERTY) else
		$error("valid det is unkown %m");

	// det should be 0 after reset
	property output_after_reset_PROPERTY(logic out);
		@(posedge clock)
			disable iff(!has_checks || !has_init_reset)
			$rose(reset_n) |-> out === 0;
	endproperty

	AMIQ_MD_OUT_DET_AFTER_RESET_CHECK : assert property (output_after_reset_PROPERTY(det)) else
		$error("det_value after reset is not correct %m");

	AMIQ_MD_OUT_DET_VALID_AFTER_RESET_CHECK : assert property (output_after_reset_PROPERTY(det_valid)) else
		$error("det_valid value after reset is not correct %m");

	AMIQ_MD_OUT_OVERFLOW_AFTER_RESET_CHECK : assert property (output_after_reset_PROPERTY(overflow)) else
		$error("overflow value after reset is not correct %m");

	// overflow should only be active if valid is active
	property overflow_only_if_valid_PROPERTY;
		@(posedge clock)
			disable iff(!reset_n || !has_checks)
			overflow |-> det_valid;
	endproperty

	AMIQ_MD_OVERFLOW_ONLY_IF_VALID_CHECK : assert property (overflow_only_if_valid_PROPERTY) else
		$error("overflow asserts without det_valid %m");

	// overflow is only 1 clock cycle long
	property overflow_is_pulse_PROPERTY;
		@(posedge clock)
			disable iff(!reset_n || !has_checks)
			overflow |=> !overflow;
	endproperty

	AMIQ_MD_OVERFLOW_IS_PULSE_CHECK : assert property (overflow_is_pulse_PROPERTY) else
		$error("overflow is not a pulse %m");
	
//	bit a = 0;
//	// a is more than 3 clock cycles
//	property a_is_more_than_3ccs;
//		@(posedge clock)
//			$rose(a) |-> a[*3:$] ##1 $fell(a);
//	endproperty
//
//	assert property (a_is_more_than_3ccs) else
//		$error("a is less than 3 clock cycles %m");

endinterface

`endif // AMIQ_DETERMINANT_IF

