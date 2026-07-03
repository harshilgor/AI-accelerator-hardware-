// mac_array.sv — Parallel MAC lanes for chunked dot products

`timescale 1ns / 1ps

module mac_array #(
    parameter int WIDTH = 16,
    parameter int LANES = 4
) (
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              valid,
    input  logic                              clear,
    input  logic signed [LANES-1:0][WIDTH-1:0] a,
    input  logic signed [LANES-1:0][WIDTH-1:0] b,
    output logic signed [2*WIDTH+1:0]         acc,
    output logic                              result_valid
);

    localparam int SUM_W  = 2 * WIDTH + 2;
    localparam int PROD_W = 2 * WIDTH;

    logic                        s1_valid;
    logic                        s1_clear;
    logic signed [LANES-1:0][PROD_W-1:0] s1_product;
    logic signed [SUM_W-1:0]     lane_sum;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
            s1_clear <= 1'b0;
            for (int i = 0; i < LANES; i++)
                s1_product[i] <= '0;
        end else begin
            s1_valid <= valid;
            s1_clear <= clear;
            for (int i = 0; i < LANES; i++)
                s1_product[i] <= a[i] * b[i];
        end
    end

    always_comb begin
        lane_sum = '0;
        for (int i = 0; i < LANES; i++)
            lane_sum = lane_sum + SUM_W'(s1_product[i]);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc          <= '0;
            result_valid <= 1'b0;
        end else begin
            result_valid <= s1_valid;

            if (s1_clear)
                acc <= '0;
            else if (s1_valid)
                acc <= acc + lane_sum;
        end
    end

endmodule
