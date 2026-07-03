// pe.sv — Systolic processing element (MAC + horizontal/vertical forward)

`timescale 1ns / 1ps

module pe #(
    parameter int WIDTH  = 16,
    parameter int ACC_W  = 48
) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        clear,
    input  logic [1:0]                  dataflow_mode,
    input  logic                        preload_weight,

    input  logic                        a_valid,
    input  logic signed [WIDTH-1:0]     a_in,
    output logic                        a_valid_out,
    output logic signed [WIDTH-1:0]     a_out,

    input  logic                        b_valid,
    input  logic signed [WIDTH-1:0]     b_in,
    output logic                        b_valid_out,
    output logic signed [WIDTH-1:0]     b_out,

    output logic signed [ACC_W-1:0]     accum
);

    import gpu_pkg::*;

    logic signed [ACC_W-1:0] acc_r;
    logic signed [WIDTH-1:0] weight_reg;
    logic                    weight_valid;

    assign accum = acc_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out       <= '0;
            b_out       <= '0;
            a_valid_out <= 1'b0;
            b_valid_out <= 1'b0;
            acc_r       <= '0;
            weight_reg  <= '0;
            weight_valid <= 1'b0;
        end else begin
            a_out       <= a_in;
            b_out       <= b_in;
            a_valid_out <= a_valid;
            b_valid_out <= b_valid;

            if ((dataflow_mode == MODE_WEIGHT_STATIONARY) && preload_weight && b_valid) begin
                weight_reg   <= b_in;
                weight_valid <= 1'b1;
            end

            if (clear)
                acc_r <= '0;
            else if (dataflow_mode == MODE_WEIGHT_STATIONARY) begin
                if (!preload_weight && a_valid && weight_valid)
                    acc_r <= acc_r + ACC_W'(a_in * weight_reg);
            end else if (a_valid && b_valid) begin
                acc_r <= acc_r + ACC_W'(a_in * b_in);
            end
        end
    end

endmodule
