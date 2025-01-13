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

`ifndef AMIQ_DETERMINANT_DEFINES
`define AMIQ_DETERMINANT_DEFINES


`ifndef DET_BUS_WIDTH
`define DET_BUS_WIDTH 16
`endif //DET_BUS_WIDTH

`ifndef DET_MATRIX_SIZE
`define DET_MATRIX_SIZE 3
`endif// DET_MATRIX_SIZE

`ifndef DET_DELAY_MAX_VALUE
`define DET_DELAY_MAX_VALUE 2000
`endif // DET_DELAY_MAX_VALUE

`ifndef DET_MIN_RESET_THRESHOLD
`define DET_MIN_RESET_THRESHOLD 3
`endif // DET_MIN_RESET_THRESHOLD

`ifndef DET_MAX_RESET_THRESHOLD
`define DET_MAX_RESET_THRESHOLD 30
`endif // DET_MAX_RESET_THRESHOLD

`endif // AMIQ_DETERMINANT_DEFINES
