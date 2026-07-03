// act_pkg.sv — Activation function IDs for the VAU

`timescale 1ns / 1ps

package act_pkg;

    localparam int ACT_LUT_SEGMENTS = 64;
    localparam int ACT_SEG_W        = 6;
    localparam int ACT_FRAC_W       = 10;
    localparam int ACT_Q_W          = 32;
    localparam int ACT_X_MIN_Q      = -32'sd524288;   // -8.0 in Q16.16
    localparam int ACT_X_MAX_Q      = 32'sd524288;    // +8.0 in Q16.16
    localparam int ACT_SEG_SHIFT    = 16 - ACT_SEG_W; // frac bits above segment index

    typedef enum logic [1:0] {
        ACT_RELU = 2'd0,
        ACT_GELU = 2'd1,
        ACT_SILU = 2'd2
    } act_mode_e;

endpackage
