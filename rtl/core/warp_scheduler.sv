// warp_scheduler.sv — Warp scheduler with kernel instruction ROM
//
// Each warp runs CLEAR → MAC(chunk0) → MAC(chunk1) → HALT sequentially.
// Warps share the MAC unit; the next warp starts only after the prior halts.

`timescale 1ns / 1ps

module warp_scheduler #(
    parameter int NUM_WARPS  = 2,
    parameter int PIPE_STAGES = 2
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,

    output logic                               instr_valid,
    output logic [31:0]                        instr,
    output logic [$clog2(NUM_WARPS)-1:0]       warp_id,
    output logic                               all_done,
    output logic [31:0]                        issue_instr_o,
    output logic [WARP_W-1:0]                  issue_warp_o,
    output logic                               halt_pulse,
    output logic [WARP_W-1:0]                  halt_warp_o,
    output logic                               mac_valid_o,
    output logic                               clear_valid_o
);

    localparam int INSTR_W = 32;

    localparam int WARP_W = (NUM_WARPS <= 1) ? 1 : $clog2(NUM_WARPS);
    localparam int PC_W   = 3;

    localparam logic [INSTR_W-1:0] KERNEL_CLEAR = 32'h1000_0000;
    localparam logic [INSTR_W-1:0] KERNEL_MAC0   = 32'h2000_0000;
    localparam logic [INSTR_W-1:0] KERNEL_MAC1   = 32'h2100_0000;
    localparam logic [INSTR_W-1:0] KERNEL_HALT   = 32'hF000_0000;

    function automatic logic [INSTR_W-1:0] kernel_fetch(input logic [PC_W-1:0] pc_val);
        case (pc_val)
            3'd0: kernel_fetch = KERNEL_CLEAR;
            3'd1: kernel_fetch = KERNEL_MAC0;
            3'd2: kernel_fetch = KERNEL_MAC1;
            default: kernel_fetch = KERNEL_HALT;
        endcase
    endfunction

    typedef enum logic [1:0] { S_IDLE, S_RUN, S_STALL, S_FINISH } state_t;

    state_t                   state;
    logic [PC_W-1:0]          pc      [NUM_WARPS];
    logic                     halted  [NUM_WARPS];
    logic [WARP_W-1:0]        active_warp;
    logic [WARP_W-1:0]        next_rr;
    logic [PIPE_STAGES:0]     stall_cnt;
    logic                     all_warps_halted;

    function automatic logic [WARP_W-1:0] find_next_warp(
        input logic [WARP_W-1:0] start_idx
    );
        logic found;
        int idx;
        find_next_warp = start_idx;
        found = 1'b0;
        for (int i = 0; i < NUM_WARPS; i++) begin
            idx = int'(start_idx) + i;
            if (idx >= NUM_WARPS)
                idx = idx - NUM_WARPS;
            if (!found && !halted[idx]) begin
                find_next_warp = WARP_W'(idx);
                found = 1'b1;
            end
        end
    endfunction

    assign all_done      = (state == S_FINISH);
    assign issue_instr_o = issue_instr;
    assign issue_warp_o  = active_warp;
    assign mac_valid_o   = (state == S_RUN) && !halted[active_warp]
                           && (issue_instr[31:28] == 4'h2);
    assign clear_valid_o = (state == S_RUN) && !halted[active_warp]
                           && (issue_instr[31:28] == 4'h1);

    logic [INSTR_W-1:0] issue_instr;
    always_comb begin
        issue_instr = kernel_fetch(pc[active_warp]);
    end

    int w;

    always_comb begin
        all_warps_halted = 1'b1;
        for (int i = 0; i < NUM_WARPS; i++)
            all_warps_halted &= halted[i];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            active_warp <= '0;
            next_rr     <= '0;
            stall_cnt   <= '0;
            instr_valid <= 1'b0;
            halt_pulse  <= 1'b0;
            instr       <= '0;
            warp_id     <= '0;
            halt_warp_o <= '0;

            for (w = 0; w < NUM_WARPS; w++) begin
                pc[w]     <= '0;
                halted[w] <= 1'b0;
            end
        end else begin
            instr_valid <= 1'b0;
            halt_pulse  <= 1'b0;

            unique case (state)
                S_IDLE: begin
                    if (start) begin
                        for (w = 0; w < NUM_WARPS; w++) begin
                            pc[w]     <= '0;
                            halted[w] <= 1'b0;
                        end
                        active_warp <= '0;
                        next_rr     <= '0;
                        state       <= S_RUN;
                    end
                end

                S_RUN: begin
                    if (halted[active_warp]) begin
                        if (all_warps_halted) begin
                            state <= S_FINISH;
                        end else begin
                            active_warp <= find_next_warp(next_rr);
                            next_rr     <= find_next_warp(next_rr) + WARP_W'(1);
                        end
                    end else begin
                        warp_id     <= active_warp;
                        instr       <= issue_instr;
                        instr_valid <= 1'b1;

                        if (issue_instr[31:28] == 4'hF) begin
                            halted[active_warp] <= 1'b1;
                            halt_pulse          <= 1'b1;
                            halt_warp_o         <= active_warp;
                        end else begin
                            pc[active_warp] <= pc[active_warp] + 1'b1;
                            if (issue_instr[31:28] == 4'h1 || issue_instr[31:28] == 4'h2) begin
                                stall_cnt <= PIPE_STAGES[PIPE_STAGES:0];
                                state     <= S_STALL;
                            end
                        end
                    end
                end

                S_STALL: begin
                    if (stall_cnt <= 1)
                        state <= S_RUN;
                    stall_cnt <= stall_cnt - 1'b1;
                end

                S_FINISH: begin
                    if (!start)
                        state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
