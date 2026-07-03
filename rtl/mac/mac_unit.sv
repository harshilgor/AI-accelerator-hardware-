// mac_unit.sv — Multiply-Accumulate unit (GPU building block)

`timescale 1ns / 1ps

module mac_unit #(
    parameter int WIDTH = 16
) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        valid,
    input  logic                        clear,
    input  logic signed [WIDTH-1:0]     a,
    input  logic signed [WIDTH-1:0]     b,
    output logic signed [2*WIDTH-1:0]   acc,
    output logic                        acc_valid
);

    localparam int ACC_W = 2 * WIDTH;

    logic                        s1_valid;
    logic                        s1_clear;
    logic signed [ACC_W-1:0]     s1_product;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid   <= 1'b0;
            s1_clear   <= 1'b0;
            s1_product <= '0;
        end else begin
            s1_valid   <= valid;
            s1_clear   <= clear;
            s1_product <= a * b;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc       <= '0;
            acc_valid <= 1'b0;
        end else begin
            acc_valid <= s1_valid;

            if (s1_clear)
                acc <= '0;
            else if (s1_valid)
                acc <= acc + s1_product;
        end
    end

endmodule
