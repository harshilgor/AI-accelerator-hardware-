// matrix_mem.sv — SRAM banks A, B, C (raw), D (activated) with host + split ctrl R/W

`timescale 1ns / 1ps

module matrix_mem #(
    parameter int SIZE   = 16,
    parameter int WIDTH  = 16,
    parameter int ACC_W  = 48
) (
    input  logic clk,
    input  logic rst_n,

    // Host port (single transaction)
    input  logic                    host_en,
    input  logic                    host_wen,
    input  logic [2:0]              host_bank,
    input  logic [$clog2(SIZE*SIZE)-1:0] host_addr,
    input  logic signed [ACC_W-1:0] host_wdata,
    output logic signed [ACC_W-1:0] host_rdata,

    // Accelerator legacy single port (load A/B, store C)
    input  logic                         ctrl_en,
    input  logic                         ctrl_wen,
    input  logic [2:0]                   ctrl_bank,
    input  logic [$clog2(SIZE*SIZE)-1:0] ctrl_addr,
    input  logic signed [ACC_W-1:0]      ctrl_wdata,
    output logic signed [ACC_W-1:0]      ctrl_rdata,

    // Split port for VAU: read bank C while writing bank D in the same cycle
    input  logic                         ctrl_rd_en,
    input  logic [2:0]                   ctrl_rd_bank,
    input  logic [$clog2(SIZE*SIZE)-1:0] ctrl_rd_addr,
    output logic signed [ACC_W-1:0]      ctrl_rd_rdata,

    input  logic                         ctrl_wr_en,
    input  logic [2:0]                   ctrl_wr_bank,
    input  logic [$clog2(SIZE*SIZE)-1:0] ctrl_wr_addr,
    input  logic signed [ACC_W-1:0]      ctrl_wr_wdata
);

    localparam int ELEMS  = SIZE * SIZE;
    localparam int ADDR_W = (ELEMS <= 1) ? 1 : $clog2(ELEMS);

    logic                    a_wen;
    logic [ADDR_W-1:0]       a_addr;
    logic signed [WIDTH-1:0] a_wdata;
    logic signed [WIDTH-1:0] a_rdata;

    logic                    b_wen;
    logic [ADDR_W-1:0]       b_addr;
    logic signed [WIDTH-1:0] b_wdata;
    logic signed [WIDTH-1:0] b_rdata;

    logic                    c_wen;
    logic [ADDR_W-1:0]       c_addr;
    logic signed [ACC_W-1:0] c_wdata;
    logic signed [ACC_W-1:0] c_rdata;

    logic                    d_wen;
    logic [ADDR_W-1:0]       d_addr;
    logic signed [WIDTH-1:0] d_wdata;
    logic signed [WIDTH-1:0] d_rdata;

    logic host_active;
    logic [2:0] host_bank_i;
    logic [ADDR_W-1:0] host_addr_i;
    logic host_wen_i;
    logic signed [ACC_W-1:0] host_wdata_i;

    assign host_active  = host_en && !ctrl_en && !ctrl_rd_en && !ctrl_wr_en;
    assign host_bank_i  = host_bank;
    assign host_addr_i  = host_addr;
    assign host_wen_i   = host_wen;
    assign host_wdata_i = host_wdata;

    logic signed [ACC_W-1:0] host_mux_rdata;
    logic signed [ACC_W-1:0] ctrl_mux_rdata;
    logic signed [ACC_W-1:0] ctrl_rd_mux_rdata;

    always_comb begin
        host_mux_rdata = '0;
        case (host_bank_i)
            3'd0: host_mux_rdata = ACC_W'(a_rdata);
            3'd1: host_mux_rdata = ACC_W'(b_rdata);
            3'd2: host_mux_rdata = c_rdata;
            3'd3: host_mux_rdata = ACC_W'(d_rdata);
            default: host_mux_rdata = '0;
        endcase
    end

    always_comb begin
        ctrl_mux_rdata = '0;
        case (ctrl_bank)
            3'd0: ctrl_mux_rdata = ACC_W'(a_rdata);
            3'd1: ctrl_mux_rdata = ACC_W'(b_rdata);
            3'd2: ctrl_mux_rdata = c_rdata;
            3'd3: ctrl_mux_rdata = ACC_W'(d_rdata);
            default: ctrl_mux_rdata = '0;
        endcase
    end

    always_comb begin
        ctrl_rd_mux_rdata = '0;
        case (ctrl_rd_bank)
            3'd0: ctrl_rd_mux_rdata = ACC_W'(a_rdata);
            3'd1: ctrl_rd_mux_rdata = ACC_W'(b_rdata);
            3'd2: ctrl_rd_mux_rdata = c_rdata;
            3'd3: ctrl_rd_mux_rdata = ACC_W'(d_rdata);
            default: ctrl_rd_mux_rdata = '0;
        endcase
    end

    assign host_rdata    = host_active ? host_mux_rdata : '0;
    assign ctrl_rdata    = ctrl_en ? ctrl_mux_rdata : '0;
    assign ctrl_rd_rdata = ctrl_rd_en ? ctrl_rd_mux_rdata : '0;

    always_comb begin
        a_wen   = 1'b0;
        a_addr  = '0;
        a_wdata = '0;
        b_wen   = 1'b0;
        b_addr  = '0;
        b_wdata = '0;
        c_wen   = 1'b0;
        c_addr  = '0;
        c_wdata = '0;
        d_wen   = 1'b0;
        d_addr  = '0;
        d_wdata = '0;

        if (host_active) begin
            case (host_bank_i)
                3'd0: begin
                    a_addr = host_addr_i;
                    if (host_wen_i) begin
                        a_wen   = 1'b1;
                        a_wdata = WIDTH'(host_wdata_i);
                    end
                end
                3'd1: begin
                    b_addr = host_addr_i;
                    if (host_wen_i) begin
                        b_wen   = 1'b1;
                        b_wdata = WIDTH'(host_wdata_i);
                    end
                end
                3'd2: begin
                    c_addr = host_addr_i;
                    if (host_wen_i) begin
                        c_wen   = 1'b1;
                        c_wdata = host_wdata_i;
                    end
                end
                3'd3: begin
                    d_addr = host_addr_i;
                    if (host_wen_i) begin
                        d_wen   = 1'b1;
                        d_wdata = WIDTH'(host_wdata_i);
                    end
                end
                default: ;
            endcase
        end

        if (ctrl_en) begin
            case (ctrl_bank)
                3'd0: begin
                    a_addr = ctrl_addr;
                    if (ctrl_wen) begin
                        a_wen   = 1'b1;
                        a_wdata = WIDTH'(ctrl_wdata);
                    end
                end
                3'd1: begin
                    b_addr = ctrl_addr;
                    if (ctrl_wen) begin
                        b_wen   = 1'b1;
                        b_wdata = WIDTH'(ctrl_wdata);
                    end
                end
                3'd2: begin
                    c_addr = ctrl_addr;
                    if (ctrl_wen) begin
                        c_wen   = 1'b1;
                        c_wdata = ctrl_wdata;
                    end
                end
                3'd3: begin
                    d_addr = ctrl_addr;
                    if (ctrl_wen) begin
                        d_wen   = 1'b1;
                        d_wdata = WIDTH'(ctrl_wdata);
                    end
                end
                default: ;
            endcase
        end

        if (ctrl_rd_en) begin
            case (ctrl_rd_bank)
                3'd0: a_addr = ctrl_rd_addr;
                3'd1: b_addr = ctrl_rd_addr;
                3'd2: c_addr = ctrl_rd_addr;
                3'd3: d_addr = ctrl_rd_addr;
                default: ;
            endcase
        end

        if (ctrl_wr_en) begin
            case (ctrl_wr_bank)
                3'd0: begin
                    a_wen   = 1'b1;
                    a_addr  = ctrl_wr_addr;
                    a_wdata = WIDTH'(ctrl_wr_wdata);
                end
                3'd1: begin
                    b_wen   = 1'b1;
                    b_addr  = ctrl_wr_addr;
                    b_wdata = WIDTH'(ctrl_wr_wdata);
                end
                3'd2: begin
                    c_wen   = 1'b1;
                    c_addr  = ctrl_wr_addr;
                    c_wdata = ctrl_wr_wdata;
                end
                3'd3: begin
                    d_wen   = 1'b1;
                    d_addr  = ctrl_wr_addr;
                    d_wdata = WIDTH'(ctrl_wr_wdata);
                end
                default: ;
            endcase
        end
    end

    sync_sram #(.DEPTH(ELEMS), .WIDTH(WIDTH), .ADDR_W(ADDR_W)) u_sram_a (
        .clk(clk), .wen(a_wen), .addr(a_addr), .wdata(a_wdata), .rdata(a_rdata));
    sync_sram #(.DEPTH(ELEMS), .WIDTH(WIDTH), .ADDR_W(ADDR_W)) u_sram_b (
        .clk(clk), .wen(b_wen), .addr(b_addr), .wdata(b_wdata), .rdata(b_rdata));
    sync_sram #(.DEPTH(ELEMS), .WIDTH(ACC_W), .ADDR_W(ADDR_W)) u_sram_c (
        .clk(clk), .wen(c_wen), .addr(c_addr), .wdata(c_wdata), .rdata(c_rdata));
    sync_sram #(.DEPTH(ELEMS), .WIDTH(WIDTH), .ADDR_W(ADDR_W)) u_sram_d (
        .clk(clk), .wen(d_wen), .addr(d_addr), .wdata(d_wdata), .rdata(d_rdata));

endmodule
