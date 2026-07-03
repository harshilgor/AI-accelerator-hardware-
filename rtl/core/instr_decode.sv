// instr_decode.sv — Combinational instruction decoder

`timescale 1ns / 1ps

module instr_decode (
    input  logic [31:0] instr,
    output logic        op_clear,
    output logic        op_mac,
    output logic        op_halt,
    output logic        op_nop,
    output logic [1:0]  chunk_idx
);

    logic [3:0] opcode;

    assign opcode    = instr[31:28];
    assign chunk_idx = instr[25:24];
    assign op_clear  = (opcode == 4'h1);
    assign op_mac    = (opcode == 4'h2);
    assign op_halt   = (opcode == 4'hF);
    assign op_nop    = (opcode == 4'h0);

endmodule
