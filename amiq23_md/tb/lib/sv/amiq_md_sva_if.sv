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
// Creation Date    : Aug 14, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Block interface used for block checking
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_SVA_IF
`define AMIQ_MD_SVA_IF

`include "amiq_md_defines.svh"

interface amiq_md_sva_if(
		// syncronization signal
		input logic clock,
		// bring to initial state signal
		input logic reset_n
	);

	// flag that enables/diasbles checks
	bit has_checks = 1;

	// reset should be held for the minimum threshold
	property reset_threshold_PROPERTY;
		@(posedge clock)
			disable iff($isunknown(clock) || $isunknown(reset_n) || !has_checks)
			$fell(reset_n) |-> !reset_n[*`MIN_RESET_THRESHOLD:$] ##1 $rose(reset_n);
	endproperty

	AMIQ_MD_RESET_3CCS_CHECK : assert property (reset_threshold_PROPERTY) else
		$error("reset is shorter than %d clock cycles %m", `MIN_RESET_THRESHOLD);
	
endinterface

`endif // AMIQ_MD_SVA_IF

