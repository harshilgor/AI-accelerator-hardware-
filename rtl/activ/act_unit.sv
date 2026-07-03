// act_unit.sv — Pipelined scalar activation (ReLU / piecewise-linear GeLU / SiLU)

`timescale 1ns / 1ps

module act_unit #(
    parameter int ACC_W  = 48,
    parameter int OUT_W  = 16,
    parameter int SEG_W  = 6,
    parameter int FRAC_W = 14
) (
    input  logic clk,
    input  logic rst_n,
    input  logic valid_in,
    input  logic [1:0] act_mode,
    input  logic signed [ACC_W-1:0] data_in,

    output logic valid_out,
    output logic signed [OUT_W-1:0] data_out
);

    import act_pkg::*;

    localparam int Q_W     = ACT_Q_W;
    localparam int PROD_W  = Q_W + FRAC_W;

    logic        s0_valid;
    logic [1:0]  s0_mode;
    logic signed [Q_W-1:0] s0_x_q;
    logic [SEG_W-1:0] s0_seg;
    logic [FRAC_W-1:0] s0_frac;
    logic        s0_relu_path;

    logic        s1_valid;
    logic [1:0]  s1_mode;
    logic signed [Q_W-1:0] s1_x_q;
    logic signed [Q_W-1:0] s1_y_q;
    logic        s1_relu_path;

    logic        s2_valid;
    logic signed [OUT_W-1:0] s2_out;

    logic signed [Q_W-1:0] x_scaled;
    logic signed [Q_W-1:0] x_clamped;
    logic signed [Q_W-1:0] x_offset;
    logic signed [Q_W-1:0] lut_y;
    logic signed [Q_W-1:0] lut_m;
    logic signed [PROD_W-1:0] interp_prod;
    logic signed [Q_W-1:0] interp_y;

    function automatic logic signed [Q_W-1:0] to_x_q(
        input logic signed [ACC_W-1:0] v
    );
        logic signed [ACC_W-1:0] promoted;
        promoted = v <<< 16;
        if (promoted > ACT_X_MAX_Q)
            return ACT_X_MAX_Q;
        if (promoted < ACT_X_MIN_Q)
            return ACT_X_MIN_Q;
        return Q_W'(promoted);
    endfunction

    function automatic logic signed [OUT_W-1:0] quantize_out(
        input logic signed [Q_W-1:0] y_q
    );
        logic signed [Q_W-1:0] rounded;
        logic signed [OUT_W-1:0] out;
        rounded = y_q >>> 16;
        if (rounded > (1 <<< (OUT_W - 1)) - 1)
            return OUT_W'((1 <<< (OUT_W - 1)) - 1);
        if (rounded < -(1 <<< (OUT_W - 1)))
            return OUT_W'(-(1 <<< (OUT_W - 1)));
        out = OUT_W'(rounded);
        return out;
    endfunction

    assign x_scaled  = to_x_q(data_in);
    assign x_clamped = x_scaled;
    assign x_offset  = x_clamped - ACT_X_MIN_Q;

    act_lut_rom #(
        .SEGMENTS (ACT_LUT_SEGMENTS),
        .SEG_W    (SEG_W)
    ) u_lut (
        .act_mode (s0_mode),
        .seg_idx  (s0_seg),
        .y_base   (lut_y),
        .slope    (lut_m)
    );

    assign interp_prod = PROD_W'(lut_m) * PROD_W'(s0_frac);
    assign interp_y    = lut_y + Q_W'(interp_prod >>> FRAC_W);

    // Stage 0 — scale input, compute segment index + fraction
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_valid     <= 1'b0;
            s0_mode      <= ACT_RELU;
            s0_x_q       <= '0;
            s0_seg       <= '0;
            s0_frac      <= '0;
            s0_relu_path <= 1'b0;
        end else begin
            s0_valid <= valid_in;
            s0_mode  <= act_mode;
            s0_x_q   <= x_scaled;
            s0_relu_path <= (act_mode == ACT_RELU);
            if (x_offset < 0)
                s0_seg <= '0;
            else if (x_offset > (ACT_X_MAX_Q - ACT_X_MIN_Q))
                s0_seg <= {SEG_W{1'b1}};
            else
                s0_seg <= x_offset[19:14];
            s0_frac <= x_offset[FRAC_W-1:0];
        end
    end

    // Stage 1 — LUT interpolate or ReLU pass-through
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid     <= 1'b0;
            s1_mode      <= ACT_RELU;
            s1_x_q       <= '0;
            s1_y_q       <= '0;
            s1_relu_path <= 1'b0;
        end else begin
            s1_valid     <= s0_valid;
            s1_mode      <= s0_mode;
            s1_x_q       <= s0_x_q;
            s1_relu_path <= s0_relu_path;
            if (s0_relu_path) begin
                if (s0_x_q < 0)
                    s1_y_q <= '0;
                else
                    s1_y_q <= s0_x_q;
            end else begin
                s1_y_q <= interp_y;
            end
        end
    end

    // Stage 2 — quantize to OUT_W
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 1'b0;
            s2_out   <= '0;
        end else begin
            s2_valid <= s1_valid;
            s2_out   <= quantize_out(s1_y_q);
        end
    end

    assign valid_out = s2_valid;
    assign data_out  = s2_out;

endmodule
