// systolic_gemm.sv — Skewed-input controller + systolic mesh (C = A x B)
// OS: single-pass A/B skewed stream.  WS: K-step preload B[k][:] then stream A[:][k].

`timescale 1ns / 1ps

module systolic_gemm #(
    parameter int SIZE  = 16,
    parameter int WIDTH = 16,
    parameter int ACC_W = 48
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [1:0] dataflow_mode,

    input  logic signed [SIZE*SIZE*WIDTH-1:0] matrix_a_flat,
    input  logic signed [SIZE*SIZE*WIDTH-1:0] matrix_b_flat,

    output logic                               done,
    output logic                               busy,
    output logic        [15:0]                 cycle_count,
    output logic signed [SIZE*SIZE*ACC_W-1:0]  c_flat
);

    import gpu_pkg::*;

    typedef enum logic [2:0] { S_IDLE, S_CLEAR, S_PRELOAD, S_RUN, S_DRAIN, S_DONE } state_t;

    state_t state;

    logic signed [SIZE-1:0][WIDTH-1:0]     a_left;
    logic        [SIZE-1:0]                a_left_valid;
    logic signed [SIZE-1:0][WIDTH-1:0]     b_top;
    logic        [SIZE-1:0]                b_top_valid;

    logic signed [SIZE-1:0][SIZE-1:0][ACC_W-1:0] c;

    logic        mesh_clear;
    logic        mesh_preload_weight;
    logic [15:0] tick;
    logic [15:0] run_len;
    logic [15:0] slice_len;
    logic [$clog2(SIZE+1)-1:0] k_index;

    function automatic logic signed [WIDTH-1:0] get_a(input int row, input int col);
        int idx;
        idx = (row * SIZE + col) * WIDTH;
        get_a = matrix_a_flat[idx +: WIDTH];
    endfunction

    function automatic logic signed [WIDTH-1:0] get_b(input int row, input int col);
        int idx;
        idx = (row * SIZE + col) * WIDTH;
        get_b = matrix_b_flat[idx +: WIDTH];
    endfunction

    systolic_mesh #(
        .SIZE  (SIZE),
        .WIDTH (WIDTH),
        .ACC_W (ACC_W)
    ) u_mesh (
        .clk            (clk),
        .rst_n          (rst_n),
        .clear          (mesh_clear),
        .dataflow_mode  (dataflow_mode),
        .preload_weight (mesh_preload_weight),
        .a_left         (a_left),
        .a_left_valid   (a_left_valid),
        .b_top          (b_top),
        .b_top_valid    (b_top_valid),
        .c              (c)
    );

    genvar gi, gj;
    generate
        for (gi = 0; gi < SIZE; gi++) begin : pack_c
            for (gj = 0; gj < SIZE; gj++) begin : pack_cj
                localparam int CIDX = (gi * SIZE + gj) * ACC_W;
                assign c_flat[CIDX +: ACC_W] = c[gi][gj];
            end
        end
    endgenerate

    assign busy        = (state != S_IDLE) && (state != S_DONE);
    assign done        = (state == S_DONE);
    assign cycle_count = tick;
    assign run_len     = 16'(3 * SIZE - 1);
    assign slice_len   = 16'(2 * SIZE - 2);
    assign mesh_preload_weight = (state == S_PRELOAD) && (dataflow_mode == MODE_WEIGHT_STATIONARY);

    always_comb begin
        integer k, i, j;
        int     k_cur;
        a_left       = '0;
        a_left_valid = '0;
        b_top        = '0;
        b_top_valid  = '0;
        k_cur        = int'(k_index);

        if (dataflow_mode == MODE_WEIGHT_STATIONARY) begin
            if (state == S_PRELOAD) begin
                for (j = 0; j < SIZE; j++) begin
                    if (tick == j[15:0]) begin
                        b_top[j]       = get_b(k_cur, j);
                        b_top_valid[j] = 1'b1;
                    end
                end
            end else if (state == S_RUN) begin
                for (i = 0; i < SIZE; i++) begin
                    if (tick == i[15:0]) begin
                        a_left[i]       = get_a(i, k_cur);
                        a_left_valid[i] = 1'b1;
                    end
                end
            end
        end else if (state == S_RUN) begin
            for (k = 0; k < SIZE; k++) begin
                for (i = 0; i < SIZE; i++) begin
                    if (tick == i + k) begin
                        a_left[i]       = get_a(i, k);
                        a_left_valid[i] = 1'b1;
                    end
                end
                for (j = 0; j < SIZE; j++) begin
                    if (tick == j + k) begin
                        b_top[j]       = get_b(k, j);
                        b_top_valid[j] = 1'b1;
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= S_IDLE;
            tick       <= '0;
            k_index    <= '0;
            mesh_clear <= 1'b0;
        end else begin
            mesh_clear <= 1'b0;

            case (state)
                S_IDLE: begin
                    tick <= '0;
                    if (start) begin
                        mesh_clear <= 1'b1;
                        k_index    <= '0;
                        state      <= S_CLEAR;
                    end
                end

                S_CLEAR: begin
                    if (dataflow_mode == MODE_WEIGHT_STATIONARY)
                        state <= S_PRELOAD;
                    else
                        state <= S_RUN;
                    tick <= '0;
                end

                S_PRELOAD: begin
                    if (tick >= slice_len) begin
                        state <= S_RUN;
                        tick  <= '0;
                    end else begin
                        tick <= tick + 16'd1;
                    end
                end

                S_RUN: begin
                    if (dataflow_mode == MODE_WEIGHT_STATIONARY) begin
                        if (tick >= slice_len) begin
                            if (k_index + 1 >= SIZE[($clog2(SIZE+1)-1):0]) begin
                                state <= S_DRAIN;
                                tick  <= run_len;
                            end else begin
                                k_index <= k_index + 1'b1;
                                state   <= S_PRELOAD;
                                tick    <= '0;
                            end
                        end else begin
                            tick <= tick + 16'd1;
                        end
                    end else begin
                        if (tick >= run_len)
                            state <= S_DRAIN;
                        else
                            tick <= tick + 16'd1;
                    end
                end

                S_DRAIN: begin
                    if (tick >= run_len + SIZE[15:0])
                        state <= S_DONE;
                    else
                        tick <= tick + 16'd1;
                end

                S_DONE: begin
                    if (!start)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
