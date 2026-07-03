// systolic_gemm_tb.sv — Systolic GEMM test (SIZE from gpu_pkg, timing diagram output)

`timescale 1ns / 1ps

module systolic_gemm_tb
    import gpu_pkg::*;
;

    localparam int SIZE  = SYSTOLIC_SIZE;
    localparam int WIDTH = SYSTOLIC_WIDTH;
    localparam int ACC_W = SYSTOLIC_ACC_W;
    localparam int RUN_CYCLES = 3 * SIZE - 1;
    localparam int TOTAL_PES  = SIZE * SIZE;

    logic clk;
    logic rst_n;
    logic start;
    logic [1:0] dataflow_mode;

    logic signed [SIZE*SIZE*WIDTH-1:0] matrix_a_flat;
    logic signed [SIZE*SIZE*WIDTH-1:0] matrix_b_flat;
    logic signed [SIZE*SIZE*ACC_W-1:0] c_flat;

    logic        done;
    logic        busy;
    logic [15:0] cycle_count;

    int errors;
    int i;
    int j;
    int k;
    int t;

    systolic_gemm #(
        .SIZE  (SIZE),
        .WIDTH (WIDTH),
        .ACC_W (ACC_W)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (start),
        .dataflow_mode  (dataflow_mode),
        .matrix_a_flat  (matrix_a_flat),
        .matrix_b_flat  (matrix_b_flat),
        .done           (done),
        .busy           (busy),
        .cycle_count    (cycle_count),
        .c_flat         (c_flat)
    );

    function automatic logic signed [WIDTH-1:0] get_a(input int row, input int col);
        get_a = matrix_a_flat[(row * SIZE + col) * WIDTH +: WIDTH];
    endfunction

    function automatic logic signed [WIDTH-1:0] get_b(input int row, input int col);
        get_b = matrix_b_flat[(row * SIZE + col) * WIDTH +: WIDTH];
    endfunction

    function automatic logic signed [ACC_W-1:0] get_c(input int row, input int col);
        get_c = c_flat[(row * SIZE + col) * ACC_W +: ACC_W];
    endfunction

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/systolic_gemm_tb.vcd");
        $dumpvars(0, systolic_gemm_tb);
        if (SIZE <= 8)
            $dumpvars(0, dut.u_mesh);
    end

    task automatic set_a(input int row, input int col, input int val);
        matrix_a_flat[(row * SIZE + col) * WIDTH +: WIDTH] = WIDTH'(val);
    endtask

    task automatic set_b(input int row, input int col, input int val);
        matrix_b_flat[(row * SIZE + col) * WIDTH +: WIDTH] = WIDTH'(val);
    endtask

    task automatic load_demo_matrices();
        for (i = 0; i < SIZE; i++)
            for (j = 0; j < SIZE; j++) begin
                set_a(i, j, (i + 1) * (j + 1));
                set_b(i, j, (i == j) ? 1 : 0);
            end
    endtask

    function automatic int ref_c(input int row, input int col);
        int sum;
        sum = 0;
        for (k = 0; k < SIZE; k++)
            sum += (row + 1) * (k + 1) * ((k == col) ? 1 : 0);
        return sum;
    endfunction

    task automatic print_cycle_row(input int cyc);
        $write("cycle %3d | A: ", cyc);
        for (i = 0; i < SIZE; i++) begin
            logic has_a;
            int   a_val;
            has_a = 1'b0;
            a_val = 0;
            for (k = 0; k < SIZE; k++)
                if (cyc == i + k) begin
                    has_a = 1'b1;
                    a_val = get_a(i, k);
                end
            if (has_a)
                $write("r%0d=%3d ", i, a_val);
        end
        $write("|| B: ");
        for (j = 0; j < SIZE; j++) begin
            logic has_b;
            int   b_val;
            has_b = 1'b0;
            b_val = 0;
            for (k = 0; k < SIZE; k++)
                if (cyc == j + k) begin
                    has_b = 1'b1;
                    b_val = get_b(k, j);
                end
            if (has_b)
                $write("c%0d=%3d ", j, b_val);
        end
        $display("");
    endtask

    task automatic print_timing_diagram();
        int max_cycle;
        max_cycle = 3 * SIZE - 2;

        $display("");
        $display("================================================================");
        $display(" SYSTOLIC GEMM — %0dx%0d mesh (%0d PEs)", SIZE, SIZE, TOTAL_PES);
        $display("================================================================");
        $display(" Schedule: A[i][k] -> row i @ cycle (i+k); B[k][j] -> col j @ cycle (j+k)");
        $display(" PE(i,j) MAC @ cycle (i+j+k), k=0..%0d; run_len=%0d cycles", SIZE - 1, RUN_CYCLES);
        $display("");

        if (SIZE <= 8) begin
            for (t = 0; t <= max_cycle; t++)
                print_cycle_row(t);

            $display("");
            $display("PE MAC meet cycles (i+j+k):");
            for (i = 0; i < SIZE; i++) begin
                $write("  row %0d: ", i);
                for (j = 0; j < SIZE; j++) begin
                    $write("PE(%0d,%0d)[", i, j);
                    for (k = 0; k < SIZE; k++) begin
                        $write("%0d", i + j + k);
                        if (k < SIZE - 1)
                            $write(",");
                    end
                    $write("] ");
                end
                $display("");
            end
        end else begin
            $display("(Compact view — full diagram: py scripts/show_systolic_timing.py --size 8)");
            $display("");
            for (t = 0; t < 4; t++)
                print_cycle_row(t);
            $display("  ...");
            for (t = max_cycle - 3; t <= max_cycle; t++)
                print_cycle_row(t);
            $display("");
            $display("Corner PE meet times:");
            $display("  PE(0,0):        k cycles 0..%0d", SIZE - 1);
            $display("  PE(%0d,%0d): last MAC @ cycle %0d",
                     SIZE - 1, SIZE - 1, 3 * SIZE - 3);
        end
        $display("================================================================");
        $display("");
    endtask

    task automatic wait_done();
        int guard;
        guard = 0;
        while (!done && guard < 5000) begin
            @(posedge clk);
            guard++;
        end
        if (guard >= 5000) begin
            $display("FAIL [timeout] systolic GEMM did not finish");
            errors++;
        end
    endtask

    task automatic run_and_check(
        input logic [1:0] mode,
        input string mode_name
    );
        int local_errors;
        local_errors = 0;

        dataflow_mode = mode;
        @(posedge clk);

        $display("Starting %0s mode %0dx%0d systolic GEMM (%0d PEs, B=I, C=rows of A)...",
                 mode_name, SIZE, SIZE, TOTAL_PES);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait_done();
        @(posedge clk);

        $display("[%0s] Completed in %0d controller cycles", mode_name, cycle_count);

        for (i = 0; i < SIZE; i++)
            for (j = 0; j < SIZE; j++) begin
                int exp;
                exp = ref_c(i, j);
                if (get_c(i, j) !== exp) begin
                    if (local_errors < 8)
                        $display("FAIL [%0s] C[%0d][%0d] expected=%0d got=%0d",
                                 mode_name, i, j, exp, get_c(i, j));
                    local_errors++;
                end
            end

        if (local_errors > 8)
            $display("[%0s] ... and %0d more mismatches", mode_name, local_errors - 8);

        if (local_errors == 0)
            $display("PASS [%0s %0dx%0d systolic GEMM] all %0d outputs match",
                     mode_name, SIZE, SIZE, TOTAL_PES);
        else
            $display("FAIL [%0s: %0d mismatches]", mode_name, local_errors);

        errors += local_errors;

        start = 1'b0;
        @(posedge clk);
    endtask

    initial begin
        errors = 0;
        rst_n  = 1'b0;
        start  = 1'b0;
        dataflow_mode = MODE_OUTPUT_STATIONARY;
        matrix_a_flat = '0;
        matrix_b_flat = '0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        load_demo_matrices();
        print_timing_diagram();

        run_and_check(MODE_OUTPUT_STATIONARY, "OS");
        run_and_check(MODE_WEIGHT_STATIONARY, "WS");

        $display("");
        $display("Waveforms: sim/systolic_gemm_tb.vcd");
        $display("Timing viz: py scripts/show_systolic_timing.py --size 8 --waves");
        $display("");

        if (errors == 0)
            $display("=== ALL TESTS PASSED ===");
        else
            $display("=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
