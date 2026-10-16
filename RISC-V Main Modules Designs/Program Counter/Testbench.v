`timescale 1ns / 1ps
// Self-checking testbench for the program counter.
//
// What it replaces asserted nothing: reset high, reset low, one change of
// pc_in and $finish. No expected value appeared anywhere in it.
//
// Three properties are pinned, and the first two were wrong in the design:
//
//   * the PC loads the next PC that arrives on pc_in (the output of the PC
//     mux). The original computed pc_in + 4 - and because pc_in already is
//     PC + 4 in the datapath, that advances the PC by eight, i.e. every second
//     instruction;
//   * reset starts the fetch at address 0, the first word of the program the
//     instruction memory holds. The original copied pc_in, which the datapath
//     derives from pc_out and which is therefore not a reset value at all;
//   * it is a register: the output moves on a clock edge, never because its
//     input changed.

module program_counter_tb;
    reg  clk, reset;
    reg  [31:0] pc_in;
    wire [31:0] pc_out;

    integer checks;
    integer failures;

    program_counter uut (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    // One clock cycle, driven from the bench rather than by an `always` block.
    // The rising edge comes first, the state is read one time unit later, and
    // the rest of the cycle follows with the clock low - so a check always sees
    // what the edge it follows produced. Driving it here also keeps every
    // `@(...)` out of the procedures: the lint pass runs Verilator with
    // --no-timing, which allows an event control only at the very top of a
    // procedure, and a task called several times inlines to more than one.
    task tick;
        begin
            clk = 1'b1;
            #1;
            clk = 1'b0;
            #9;
        end
    endtask

    task check;
        input [31:0] expected;
        begin
            checks = checks + 1;
            if (pc_out !== expected) begin
                failures = failures + 1;
                $display("FAIL pc_out=%h (want %h): pc_in=%h reset=%b",
                         pc_out, expected, pc_in, reset);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, program_counter_tb);

        checks = 0;
        failures = 0;
        clk = 1'b0;
        reset = 1'b1;
        pc_in = 32'h12345678;

        // Held in reset: the value on pc_in is ignored, the fetch starts at
        // the first word of the program.
        tick;
        check(32'h00000000);

        // Released: the PC loads what the datapath computed, and loads it as it
        // is rather than four beyond it.
        reset = 1'b0; pc_in = 32'h00001000;
        tick;
        check(32'h00001000);

        pc_in = 32'h00001004;
        tick;
        check(32'h00001004);

        pc_in = 32'hFFFFFFFC;
        tick;
        check(32'hFFFFFFFC);

        // Changing the input alone does not move the output: no clock edge
        // falls inside the two nanoseconds below.
        pc_in = 32'h00000040;
        #2;
        check(32'hFFFFFFFC);

        tick;
        check(32'h00000040);

        // And reset returns it to the first word, whatever pc_in says.
        reset = 1'b1; pc_in = 32'hDEADBEEF;
        tick;
        check(32'h00000000);

        if (failures == 0)
            $display("Program Counter: %0d check(s) passed", checks);
        else begin
            $display("Program Counter: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Program Counter check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
