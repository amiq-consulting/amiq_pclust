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
// Creation Date    : Aug 8, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Defines used all around the project
//----------------------------------------------------------------------------

`ifndef AMIQ_CLOCK_AND_RESET_DEFINES
`define AMIQ_CLOCK_AND_RESET_DEFINES

`ifndef CLK_RST_DELAY_MAX_VALUE
`define CLK_RST_DELAY_MAX_VALUE 500
`endif // CLK_RST_DELAY_MAX_VALUE

`ifndef CLK_RST_MIN_RESET_THRESHOLD
`define CLK_RST_MIN_RESET_THRESHOLD 3
`endif // CLK_RST_MIN_RESET_THRESHOLD

`ifndef CLK_RST_MAX_RESET_THRESHOLD
`define CLK_RST_MAX_RESET_THRESHOLD 30
`endif // CLK_RST_MAX_RESET_THRESHOLD

`endif // AMIQ_CLOCK_AND_RESET_DEFINES
