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

`ifndef AMIQ_MATRIX_DEFINES
`define AMIQ_MATRIX_DEFINES


`ifndef MAT_BUS_WIDTH
`define MAT_BUS_WIDTH 16
`endif // MAT_BUS_WIDTH

`ifndef MAT_DELAY_MAX_VALUE
`define MAT_DELAY_MAX_VALUE 255
`endif // MAT_DELAY_MAX_VALUE

`ifndef MAT_LENGTH_MAX_VALUE
`define MAT_LENGTH_MAX_VALUE 70
`endif // MAT_LENGTH_MAX_VALUE

`ifndef MAT_MATRIX_SIZE
`define MAT_MATRIX_SIZE 3
`endif// MAT_MATRIX_SIZE

// weights centered around the middle of the interval
`ifndef MAT_NORMAL_WEIGHTS
`define MAT_NORMAL_WEIGHTS dist { \
                            [MAT_UNDERFLOW_VALUE:-10_001] :/ 1, \
                            [-10_000 : -101] :/ 9_999, \
                            [-100 : -2] :/ 25_000, \
                            [-1:1] :/ 30_000, \
                            [2 : 100] :/ 25_000, \
                            [101 : 10_000] :/ 9_999, \
                            [10_001 : MAT_OVERFLOW_VALUE] :/ 1 \
                            }
`endif // MAT_NORMAL_WEIGHTS

`endif // AMIQ_MATRIX_DEFINES
