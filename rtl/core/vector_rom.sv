// vector_rom.sv — Operand ROM for warp dot-product kernels (simulation model)

`timescale 1ns / 1ps

module vector_rom #(
    parameter int WIDTH     = 16,
    parameter int LANES     = 4,
    parameter int NUM_WARPS = 2
) (
    input  logic [$clog2(NUM_WARPS)-1:0]       warp_id,
    input  logic [1:0]                         chunk_idx,
    output logic signed [LANES-1:0][WIDTH-1:0] a,
    output logic signed [LANES-1:0][WIDTH-1:0] b
);

    always_comb begin
        for (int lane = 0; lane < LANES; lane++) begin
            int idx;
            idx = int'(chunk_idx) * LANES + lane;

            if (warp_id == 0) begin
                a[lane] = WIDTH'(idx + 1);
                b[lane] = WIDTH'(2 * idx + 1);
            end else begin
                a[lane] = WIDTH'(1);
                b[lane] = WIDTH'(1);
            end
        end
    end

endmodule
