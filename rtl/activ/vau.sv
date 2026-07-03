// vau.sv — Vector Activation Unit (streams one element per cycle through act_unit)

`timescale 1ns / 1ps

module vau #(
    parameter int ACC_W  = 48,
    parameter int OUT_W  = 16,
    parameter int LATENCY = 3
) (
    input  logic clk,
    input  logic rst_n,

    input  logic valid_in,
    input  logic [1:0] act_mode,
    input  logic signed [ACC_W-1:0] data_in,
    output logic valid_out,
    output logic signed [OUT_W-1:0] data_out
);

    act_unit #(
        .ACC_W  (ACC_W),
        .OUT_W  (OUT_W)
    ) u_act (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .act_mode  (act_mode),
        .data_in   (data_in),
        .valid_out (valid_out),
        .data_out  (data_out)
    );

endmodule
