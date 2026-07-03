// sync_sram.sv — Single-port synchronous SRAM (simulation / BRAM inference model)
//
// One read OR write per clock cycle. Read is combinational (addr -> rdata same cycle).
// On write, the new value is visible on the next read of that address.

`timescale 1ns / 1ps

module sync_sram #(
    parameter int DEPTH  = 256,
    parameter int WIDTH  = 16,
    parameter int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  logic                    clk,
    input  logic                    wen,
    input  logic [ADDR_W-1:0]       addr,
    input  logic signed [WIDTH-1:0] wdata,
    output logic signed [WIDTH-1:0] rdata
);

    logic signed [WIDTH-1:0] mem [DEPTH];

    assign rdata = mem[addr];

    always_ff @(posedge clk) begin
        if (wen)
            mem[addr] <= wdata;
    end

endmodule
