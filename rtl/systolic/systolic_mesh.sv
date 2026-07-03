// systolic_mesh.sv — SIZE x SIZE output-stationary systolic mesh for GEMM

`timescale 1ns / 1ps

module systolic_mesh #(
    parameter int SIZE  = 16,
    parameter int WIDTH = 16,
    parameter int ACC_W = 48
) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        clear,
    input  logic [1:0]                  dataflow_mode,
    input  logic                        preload_weight,

    input  logic signed [SIZE-1:0][WIDTH-1:0]     a_left,
    input  logic        [SIZE-1:0]                a_left_valid,
    input  logic signed [SIZE-1:0][WIDTH-1:0]     b_top,
    input  logic        [SIZE-1:0]                b_top_valid,

    output logic signed [SIZE-1:0][SIZE-1:0][ACC_W-1:0] c
);

    logic signed [SIZE-1:0][SIZE-1:0][WIDTH-1:0]     a_mesh;
    logic        [SIZE-1:0][SIZE-1:0]                a_valid_mesh;
    logic signed [SIZE-1:0][SIZE-1:0][WIDTH-1:0]     b_mesh;
    logic        [SIZE-1:0][SIZE-1:0]                b_valid_mesh;

    genvar gi, gj;
    generate
        for (gi = 0; gi < SIZE; gi++) begin : gen_rows
            for (gj = 0; gj < SIZE; gj++) begin : gen_cols
                localparam int ROW = gi;
                localparam int COL = gj;

                logic signed [WIDTH-1:0] a_in;
                logic                    a_valid_in;
                logic signed [WIDTH-1:0] b_in;
                logic                    b_valid_in;

                if (COL == 0) begin : a_edge
                    assign a_in       = a_left[ROW];
                    assign a_valid_in = a_left_valid[ROW];
                end else begin : a_hop
                    assign a_in       = a_mesh[ROW][COL-1];
                    assign a_valid_in = a_valid_mesh[ROW][COL-1];
                end

                if (ROW == 0) begin : b_edge
                    assign b_in       = b_top[COL];
                    assign b_valid_in = b_top_valid[COL];
                end else begin : b_hop
                    assign b_in       = b_mesh[ROW-1][COL];
                    assign b_valid_in = b_valid_mesh[ROW-1][COL];
                end

                pe #(
                    .WIDTH (WIDTH),
                    .ACC_W (ACC_W)
                ) u_pe (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .clear       (clear),
                    .dataflow_mode (dataflow_mode),
                    .preload_weight (preload_weight),
                    .a_valid     (a_valid_in),
                    .a_in        (a_in),
                    .a_valid_out (a_valid_mesh[ROW][COL]),
                    .a_out       (a_mesh[ROW][COL]),
                    .b_valid     (b_valid_in),
                    .b_in        (b_in),
                    .b_valid_out (b_valid_mesh[ROW][COL]),
                    .b_out       (b_mesh[ROW][COL]),
                    .accum       (c[ROW][COL])
                );
            end
        end
    endgenerate

endmodule
