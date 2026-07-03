// gpu_pkg.sv — Shared types and parameters for the GPU RTL codebase
`timescale 1ns / 1ps

package gpu_pkg;

    localparam int MAC_WIDTH = 16;
    localparam int MAC_LANES = 4;
    localparam int MAC_ACC_W = 2 * MAC_WIDTH;
    localparam int MAC_ARRAY_ACC_W = 2 * MAC_WIDTH + 2;
    localparam int MAC_PIPELINE_STAGES = 2;

    localparam int NUM_WARPS  = 2;
    localparam int WARP_SIZE  = 32;
    localparam int IMEM_DEPTH = 8;

    localparam int SYSTOLIC_SIZE  = 16;
    localparam int SYSTOLIC_WIDTH = 16;
    localparam int SYSTOLIC_ACC_W = 48;
    typedef enum logic [1:0] {
        MODE_OUTPUT_STATIONARY = 2'b00,
        MODE_WEIGHT_STATIONARY = 2'b01
    } dataflow_mode_t;

    localparam int VAU_LATENCY = 3;
    localparam int MEM_BANK_A  = 0;
    localparam int MEM_BANK_B  = 1;
    localparam int MEM_BANK_C  = 2;
    localparam int MEM_BANK_D  = 3;

endpackage
