// basys3_top.v — Optional FPGA demo (Digilent Basys 3)
// Requires Vivado — skip if using web/local Yosys flow only.

`timescale 1ns / 1ps

module basys3_top (
    input  wire        CLK,
    input  wire        btnC,
    output wire [15:0] led
);

    import gpu_pkg::*;

    logic btn_sync1, btn_sync2;
    wire  rst_n = ~(btn_sync1 & btn_sync2);

    always_ff @(posedge CLK) begin
        btn_sync1 <= btnC;
        btn_sync2 <= btnC;
    end

    typedef enum logic [1:0] { S_RESET, S_CHUNK0, S_CHUNK1, S_DONE } state_t;
    state_t                state;
    logic                  valid;
    logic                  clear;
    logic [3:0]            wait_cnt;
    logic signed [MAC_LANES-1:0][MAC_WIDTH-1:0] a_lane;
    logic signed [MAC_LANES-1:0][MAC_WIDTH-1:0] b_lane;

    logic signed [MAC_ARRAY_ACC_W-1:0] acc;
    logic                              result_valid;

    mac_array mac_core (.*, .clk(CLK), .a(a_lane), .b(b_lane));

    always_ff @(posedge CLK or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_RESET;
            valid    <= 1'b0;
            clear    <= 1'b1;
            wait_cnt <= '0;
            for (int i = 0; i < MAC_LANES; i++) begin
                a_lane[i] <= '0;
                b_lane[i] <= '0;
            end
        end else begin
            clear <= 1'b0;
            valid <= 1'b0;

            unique case (state)
                S_RESET: begin
                    clear <= 1'b1;
                    if (wait_cnt == 4'd3) begin
                        wait_cnt <= '0;
                        a_lane[0] <= 16'sd1; b_lane[0] <= 16'sd1;
                        a_lane[1] <= 16'sd2; b_lane[1] <= 16'sd3;
                        a_lane[2] <= 16'sd3; b_lane[2] <= 16'sd5;
                        a_lane[3] <= 16'sd4; b_lane[3] <= 16'sd7;
                        valid <= 1'b1;
                        state <= S_CHUNK0;
                    end else begin
                        wait_cnt <= wait_cnt + 1'b1;
                    end
                end
                S_CHUNK0: begin
                    a_lane[0] <= 16'sd5;  b_lane[0] <= 16'sd9;
                    a_lane[1] <= 16'sd6;  b_lane[1] <= 16'sd11;
                    a_lane[2] <= 16'sd7;  b_lane[2] <= 16'sd13;
                    a_lane[3] <= 16'sd8;  b_lane[3] <= 16'sd15;
                    valid <= 1'b1;
                    state <= S_CHUNK1;
                end
                default: state <= S_DONE;
            endcase
        end
    end

    assign led = acc[15:0];

endmodule
