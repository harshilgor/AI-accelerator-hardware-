// systolic_accel.sv — SRAM + systolic GEMM + VAU (bank C -> bank D)

`timescale 1ns / 1ps

module systolic_accel #(
    parameter int SIZE  = 16,
    parameter int WIDTH = 16,
    parameter int ACC_W = 48
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [1:0] act_mode,
    input  logic [1:0] dataflow_mode,

    output logic done,
    output logic busy,

    input  logic                         host_en,
    input  logic                         host_wen,
    input  logic [2:0]                   host_bank,
    input  logic [$clog2(SIZE*SIZE)-1:0] host_addr,
    input  logic signed [ACC_W-1:0]      host_wdata,
    output logic signed [ACC_W-1:0]      host_rdata
);

    import gpu_pkg::*;

    localparam int ELEMS    = SIZE * SIZE;
    localparam int ADDR_W   = (ELEMS <= 1) ? 1 : $clog2(ELEMS);
    localparam int A_FLAT_W = ELEMS * WIDTH;
    localparam int C_FLAT_W = ELEMS * ACC_W;

    typedef enum logic [2:0] {
        S_IDLE,
        S_LOAD_A,
        S_LOAD_B,
        S_RUN,
        S_STORE_C,
        S_ACTIVATE,
        S_FINISH
    } state_t;

    state_t state;

    logic [$clog2(ELEMS+1)-1:0] idx;
    logic [$clog2(ELEMS+1)-1:0] act_in_cnt;
    logic [$clog2(ELEMS+1)-1:0] act_out_cnt;

    logic        ctrl_en;
    logic        ctrl_wen;
    logic [2:0]  ctrl_bank;
    logic [ADDR_W-1:0] ctrl_addr;
    logic signed [ACC_W-1:0] ctrl_wdata;
    logic signed [ACC_W-1:0] ctrl_rdata;

    logic        ctrl_rd_en;
    logic [2:0]  ctrl_rd_bank;
    logic [ADDR_W-1:0] ctrl_rd_addr;
    logic signed [ACC_W-1:0] ctrl_rd_rdata;

    logic        ctrl_wr_en;
    logic [2:0]  ctrl_wr_bank;
    logic [ADDR_W-1:0] ctrl_wr_addr;
    logic signed [ACC_W-1:0] ctrl_wr_wdata;

    logic signed [A_FLAT_W-1:0] matrix_a_flat;
    logic signed [A_FLAT_W-1:0] matrix_b_flat;
    logic signed [C_FLAT_W-1:0] c_flat;

    logic [1:0] act_mode_latched;

    logic gemm_start;
    logic gemm_done;

    logic        vau_valid_in;
    logic        vau_valid_out;
    logic signed [WIDTH-1:0] vau_data_out;

    logic [ADDR_W-1:0] vau_addr_pipe [0:VAU_LATENCY-1];
    int p;

    assign busy = (state != S_IDLE) && (state != S_FINISH);
    assign done = (state == S_FINISH);

    matrix_mem #(
        .SIZE  (SIZE),
        .WIDTH (WIDTH),
        .ACC_W (ACC_W)
    ) u_mem (
        .clk           (clk),
        .rst_n         (rst_n),
        .host_en       (host_en),
        .host_wen      (host_wen),
        .host_bank     (host_bank),
        .host_addr     (host_addr),
        .host_wdata    (host_wdata),
        .host_rdata    (host_rdata),
        .ctrl_en       (ctrl_en),
        .ctrl_wen      (ctrl_wen),
        .ctrl_bank     (ctrl_bank),
        .ctrl_addr     (ctrl_addr),
        .ctrl_wdata    (ctrl_wdata),
        .ctrl_rdata    (ctrl_rdata),
        .ctrl_rd_en    (ctrl_rd_en),
        .ctrl_rd_bank  (ctrl_rd_bank),
        .ctrl_rd_addr  (ctrl_rd_addr),
        .ctrl_rd_rdata (ctrl_rd_rdata),
        .ctrl_wr_en    (ctrl_wr_en),
        .ctrl_wr_bank  (ctrl_wr_bank),
        .ctrl_wr_addr  (ctrl_wr_addr),
        .ctrl_wr_wdata (ctrl_wr_wdata)
    );

    logic [15:0] gemm_cycles_unused;
    logic        gemm_busy_unused;

    systolic_gemm #(
        .SIZE  (SIZE),
        .WIDTH (WIDTH),
        .ACC_W (ACC_W)
    ) u_gemm (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (gemm_start),
        .dataflow_mode  (dataflow_mode),
        .matrix_a_flat  (matrix_a_flat),
        .matrix_b_flat  (matrix_b_flat),
        .done           (gemm_done),
        .busy           (gemm_busy_unused),
        .cycle_count    (gemm_cycles_unused),
        .c_flat         (c_flat)
    );

    vau #(
        .ACC_W   (ACC_W),
        .OUT_W   (WIDTH),
        .LATENCY (VAU_LATENCY)
    ) u_vau (
        .clk        (clk),
        .rst_n      (rst_n),
        .valid_in   (vau_valid_in),
        .act_mode   (act_mode_latched),
        .data_in    (ctrl_rd_rdata),
        .valid_out  (vau_valid_out),
        .data_out   (vau_data_out)
    );

    always_comb begin
        ctrl_en      = 1'b0;
        ctrl_wen     = 1'b0;
        ctrl_bank    = 3'd0;
        ctrl_addr    = '0;
        ctrl_wdata   = '0;
        ctrl_rd_en   = 1'b0;
        ctrl_rd_bank = 3'd0;
        ctrl_rd_addr = '0;
        ctrl_wr_en   = 1'b0;
        ctrl_wr_bank = 3'd0;
        ctrl_wr_addr = '0;
        ctrl_wr_wdata = '0;
        gemm_start   = 1'b0;
        vau_valid_in = 1'b0;

        case (state)
            S_LOAD_A: begin
                ctrl_en   = 1'b1;
                ctrl_bank = 3'(MEM_BANK_A);
                ctrl_addr = ADDR_W'(idx);
            end

            S_LOAD_B: begin
                ctrl_en   = 1'b1;
                ctrl_bank = 3'(MEM_BANK_B);
                ctrl_addr = ADDR_W'(idx);
            end

            S_RUN: begin
                gemm_start = 1'b1;
            end

            S_STORE_C: begin
                ctrl_en    = 1'b1;
                ctrl_wen   = 1'b1;
                ctrl_bank  = 3'(MEM_BANK_C);
                ctrl_addr  = ADDR_W'(idx);
                ctrl_wdata = c_flat[idx * ACC_W +: ACC_W];
            end

            S_ACTIVATE: begin
                if (act_in_cnt < ELEMS) begin
                    ctrl_rd_en   = 1'b1;
                    ctrl_rd_bank = 3'(MEM_BANK_C);
                    ctrl_rd_addr = ADDR_W'(act_in_cnt);
                    vau_valid_in = 1'b1;
                end
            end

            default: ;
        endcase

        if (vau_valid_out) begin
            ctrl_wr_en    = 1'b1;
            ctrl_wr_bank  = 3'(MEM_BANK_D);
            ctrl_wr_addr  = vau_addr_pipe[VAU_LATENCY - 1];
            ctrl_wr_wdata = ACC_W'(vau_data_out);
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (p = 0; p < VAU_LATENCY; p++)
                vau_addr_pipe[p] <= '0;
        end else if (state == S_ACTIVATE) begin
            if (act_in_cnt < ELEMS)
                vau_addr_pipe[0] <= ADDR_W'(act_in_cnt);
            for (p = 1; p < VAU_LATENCY; p++)
                vau_addr_pipe[p] <= vau_addr_pipe[p - 1];
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;
            idx              <= '0;
            act_in_cnt       <= '0;
            act_out_cnt      <= '0;
            act_mode_latched <= '0;
            matrix_a_flat    <= '0;
            matrix_b_flat    <= '0;
        end else begin
            case (state)
                S_IDLE: begin
                    idx        <= '0;
                    act_in_cnt <= '0;
                    if (start) begin
                        act_mode_latched <= act_mode;
                        state            <= S_LOAD_A;
                    end
                end

                S_LOAD_A: begin
                    matrix_a_flat[idx * WIDTH +: WIDTH] <= WIDTH'(ctrl_rdata);
                    if (idx + 1 >= ELEMS) begin
                        state <= S_LOAD_B;
                        idx   <= '0;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                S_LOAD_B: begin
                    matrix_b_flat[idx * WIDTH +: WIDTH] <= WIDTH'(ctrl_rdata);
                    if (idx + 1 >= ELEMS) begin
                        state <= S_RUN;
                        idx   <= '0;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                S_RUN: begin
                    if (gemm_done) begin
                        state <= S_STORE_C;
                        idx   <= '0;
                    end
                end

                S_STORE_C: begin
                    if (idx + 1 >= ELEMS) begin
                        state      <= S_ACTIVATE;
                        idx        <= '0;
                        act_in_cnt <= '0;
                        act_out_cnt <= '0;
                    end else begin
                        idx <= idx + 1'b1;
                    end
                end

                S_ACTIVATE: begin
                    if (act_in_cnt < ELEMS)
                        act_in_cnt <= act_in_cnt + 1'b1;
                    if (vau_valid_out) begin
                        act_out_cnt <= act_out_cnt + 1'b1;
                        if (act_out_cnt + 1 >= ELEMS)
                            state <= S_FINISH;
                    end
                end

                S_FINISH: begin
                    if (!start)
                        state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
