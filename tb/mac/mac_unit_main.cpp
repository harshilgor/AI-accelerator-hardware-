// C++ Verilator testbench for mac_unit (main fast simulator)

#include <cstdio>
#include <cstdlib>

#include "Vmac_unit.h"
#include "verilated.h"
#ifdef VM_TRACE
#include "verilated_vcd_c.h"
#endif

static vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

static void tick(Vmac_unit *dut
#ifdef VM_TRACE
                 , VerilatedVcdC *tfp
#endif
) {
    dut->clk = 0;
    dut->eval();
#ifdef VM_TRACE
    tfp->dump(main_time);
#endif
    main_time += 5;

    dut->clk = 1;
    dut->eval();
#ifdef VM_TRACE
    tfp->dump(main_time);
#endif
    main_time += 5;
}

static void wait_pipeline(Vmac_unit *dut
#ifdef VM_TRACE
                          , VerilatedVcdC *tfp
#endif
) {
    for (int i = 0; i < 2; i++) tick(dut
#ifdef VM_TRACE
    , tfp
#endif
    );
}

static int check_acc(Vmac_unit *dut, int expected, const char *label, int &errors
#ifdef VM_TRACE
                     , VerilatedVcdC *tfp
#endif
) {
    wait_pipeline(dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    const int got = dut->acc;
    if (got != expected) {
        std::printf("FAIL [%s] expected=%d got=%d\n", label, expected, got);
        errors++;
        return 0;
    }
    std::printf("PASS [%s] acc=%d\n", label, got);
    return 1;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Vmac_unit dut;

#ifdef VM_TRACE
    Verilated::traceEverOn(true);
    auto tfp = new VerilatedVcdC;
    dut.trace(tfp, 99);
    Verilated::mkdir("sim");
    tfp->open("sim/mac_unit_tb.vcd");
#endif

    int errors = 0;

    dut.clk = 0;
    dut.rst_n = 0;
    dut.valid = 0;
    dut.clear = 0;
    dut.a = 0;
    dut.b = 0;

    for (int i = 0; i < 4; i++) tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    dut.rst_n = 1;
    for (int i = 0; i < 2; i++) tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );

    dut.valid = 1;
    dut.a = 3;
    dut.b = 4;
    tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    dut.valid = 0;
    check_acc(&dut, 12, "single MAC 3*4", errors
#ifdef VM_TRACE
    , tfp
#endif
    );

    dut.valid = 1;
    dut.a = 2; dut.b = 5; tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    dut.a = 1; dut.b = 7; tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    dut.a = 4; dut.b = 3; tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    dut.valid = 0;
    check_acc(&dut, 41, "accumulate chain", errors
#ifdef VM_TRACE
    , tfp
#endif
    );

    dut.clear = 1; tick(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    dut.clear = 0;
    wait_pipeline(&dut
#ifdef VM_TRACE
    , tfp
#endif
    );
    if (dut.acc != 0) {
        std::printf("FAIL [clear] expected=0 got=%d\n", dut.acc);
        errors++;
    } else {
        std::printf("PASS [clear] acc=0\n");
    }

#ifdef VM_TRACE
    tfp->close();
    delete tfp;
#endif

    if (errors == 0) {
        std::printf("\n=== ALL TESTS PASSED ===\n\n");
        return 0;
    }
    std::printf("\n=== %d TEST(S) FAILED ===\n\n", errors);
    return 1;
}
