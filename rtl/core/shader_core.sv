// shader_core.sv — Shader core: scheduler + decode + MAC array

`timescale 1ns / 1ps

module shader_core #(
    parameter int WIDTH     = 16,
    parameter int LANES     = 4,
    parameter int NUM_WARPS = 2,
    parameter int ACC_W     = 2 * WIDTH + 2,
    parameter int PIPE_STAGES = 2
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,

    output logic                               done,
    output logic signed [ACC_W-1:0]            warp_acc_0,
    output logic signed [ACC_W-1:0]            warp_acc_1
);

    localparam int WARP_W = (NUM_WARPS <= 1) ? 1 : $clog2(NUM_WARPS);

    logic                               instr_valid;
    logic [31:0]                        instr;
    logic [31:0]                        issue_instr;
    logic [WARP_W-1:0]                  warp_id;
    logic [WARP_W-1:0]                  issue_warp;
    logic [WARP_W-1:0]                  halt_warp;
    logic                               halt_pulse;
    logic                               all_done;

    logic                               mac_result_valid;
    logic                               mac_valid;
    logic                               mac_clear;
    logic signed [LANES-1:0][WIDTH-1:0] vec_a;
    logic signed [LANES-1:0][WIDTH-1:0] vec_b;
    logic signed [ACC_W-1:0]              mac_acc;

    assign done      = all_done;

    warp_scheduler #(
        .NUM_WARPS   (NUM_WARPS),
        .PIPE_STAGES (PIPE_STAGES)
    ) u_scheduler (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (start),
        .instr_valid   (instr_valid),
        .instr         (instr),
        .warp_id       (warp_id),
        .all_done      (all_done),
        .issue_instr_o (issue_instr),
        .issue_warp_o  (issue_warp),
        .halt_pulse    (halt_pulse),
        .halt_warp_o   (halt_warp),
        .mac_valid_o   (mac_valid),
        .clear_valid_o (mac_clear)
    );

    vector_rom #(
        .WIDTH     (WIDTH),
        .LANES     (LANES),
        .NUM_WARPS (NUM_WARPS)
    ) u_vec_rom (
        .warp_id   (issue_warp),
        .chunk_idx (issue_instr[25:24]),
        .a         (vec_a),
        .b         (vec_b)
    );

    mac_array #(
        .WIDTH (WIDTH),
        .LANES (LANES)
    ) u_mac (
        .clk          (clk),
        .rst_n        (rst_n),
        .valid        (mac_valid),
        .clear        (mac_clear),
        .a            (vec_a),
        .b            (vec_b),
        .acc          (mac_acc),
        .result_valid (mac_result_valid)
    );

    logic                               halt_pulse_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            halt_pulse_r <= 1'b0;
        else
            halt_pulse_r <= halt_pulse;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            warp_acc_0 <= '0;
            warp_acc_1 <= '0;
        end else if (halt_pulse_r) begin
            if (halt_warp == 0)
                warp_acc_0 <= mac_acc;
            else
                warp_acc_1 <= mac_acc;
        end
    end

endmodule
