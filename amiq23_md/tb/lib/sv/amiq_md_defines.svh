//----------------------------------------------------------------------------
//                                                                          --
//     COPYRIGHT (C)                                AMIQ 2023               --
//     The document(s) may be used  and/or copied only with the written     --
//     permission from AMIQ or in accordance with the terms and             --
//     conditions  stipulated in the agreement/contract under which the     --
//     document(s) have been supplied.                                      --
//                                                                          --
//----------------------------------------------------------------------------[factorial($sqrt(`MAT_NUM_MAT_ELEMENTS))]
// Created by       : andbli
// Creation Date    : Aug 8, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Defines used all around the project
//----------------------------------------------------------------------------

`ifndef AMIQ_MD_DEFINES
`define AMIQ_MD_DEFINES

`ifndef DELAY_MAX_VALUE
`define DELAY_MAX_VALUE 255
`endif // DELAY_MAX_VALUE

`ifndef MIN_RESET_THRESHOLD
`define MIN_RESET_THRESHOLD 3
`endif // MIN_RESET_THRESHOLD

`ifndef MAX_RESET_THRESHOLD
`define MAX_RESET_THRESHOLD 30
`endif // MAX_RESET_THRESHOLD

// weights centered around the middle of the interval
`ifndef NORMAL_WEIGHTS
`define NORMAL_WEIGHTS dist { \
                            [MAT_UNDERFLOW_VALUE:-10_001] :/ 1, \
                            [-10_000 : -101] :/ 9_999, \
                            [-100 : -2] :/ 25_000, \
                            [-1:1] :/ 30_000, \
                            [2 : 100] :/ 25_000, \
                            [101 : 10_000] :/ 9_999, \
                            [10_001 : MAT_OVERFLOW_VALUE] :/ 1 \
                            };
`endif //NORMAL_WEIGHTS

// weights centered around the ends of the interval
`ifndef INVERT_WEIGHTS
`define INVERT_WEIGHTS dist { \
                            MAT_UNDERFLOW_VALUE:= 75, \
                            [MAT_UNDERFLOW_VALUE + 1:-10_001] :/ 300, \
                            [-10_000 : -101] :/ 100, \
                            [-100 : -1] :/ 20, \
                            [-1:1] :/ 10, \
                            [1 : 100] :/ 20, \
                            [101 : 10_000] :/ 100, \
                            [10_001 : MAT_OVERFLOW_VALUE - 1] :/ 300, \
                            MAT_OVERFLOW_VALUE:= 75 \
                            };
`endif //INVERT_WEIGHTS

`endif // AMIQ_MD_DEFINES
