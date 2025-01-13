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
// Description      : The clock and reset interface of the block, used for synchronization
//                  and bringing the RTL to an initial state
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_IF
`define AMIQ_CLOCK_AND_RESET_IF

interface amiq_clock_and_reset_if();

	// Used for synchronizing the other signals
	logic clock;

	// Used to bring the RTL to an initial state. This signal is active low
	logic reset_n;

	// flag that enables/disables checking on the interface
	bit has_checks = 1;

	// reset should never be unknown
	property reset_not_unkown_PROPERTY;
		@(posedge clock)
			disable iff(has_checks == 0)
			(!$isunknown(reset_n));
	endproperty

	AMIQ_MD_RESET_NOT_UNKOWN_CHECK : assert property (reset_not_unkown_PROPERTY) else
		$error("reset is unkown %m");
endinterface
`endif // AMIQ_CLOCK_AND_RESET_IF

