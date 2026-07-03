// isa_pkg.sv — GPU instruction set definitions

`timescale 1ns / 1ps

package isa_pkg;

    localparam int INSTR_W    = 32;
    localparam int OPCODE_MSB = 31;
    localparam int OPCODE_LSB = 28;
    localparam int CHUNK_MSB  = 25;
    localparam int CHUNK_LSB  = 24;

    typedef enum logic [3:0] {
        OP_NOP   = 4'h0,
        OP_CLEAR = 4'h1,
        OP_MAC   = 4'h2,
        OP_HALT  = 4'hF
    } opcode_e;

    function automatic logic [3:0] get_opcode(input logic [INSTR_W-1:0] instr);
        return instr[OPCODE_MSB:OPCODE_LSB];
    endfunction

    function automatic logic [1:0] get_chunk(input logic [INSTR_W-1:0] instr);
        return instr[CHUNK_MSB:CHUNK_LSB];
    endfunction

endpackage
