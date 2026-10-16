`timescale 1ns / 1ps
// Self-checking testbench for the PC+4 adder.
//
// What it replaces asserted nothing: `reg pc_out; wire PCPlus4;`, one bit
// toggled every 2 ns and $finish after 10 ns. No expected value appeared
// anywhere in the file, and with one-bit ports the whole result space was
// {4, 5}.
//
// The rows below are why the ports are 32 bits wide: a PC of 0x1000 has to
// come out as 0x1004, and a one-bit port can only truncate it.

module Adder_for_PCPlus4_tb;
    reg  [31:0] pc_out;
    wire [31:0] PCPlus4;

    integer checks;
    integer failures;

    Adder_for_PCPlus4 uut (
        .pc_out(pc_out),
        .PCPlus4(PCPlus4)
    );

    // Apply one PC and compare the sum. `!==` on purpose: an output still
    // holding x is a mismatch too, and `!=` would call that equal.
    task check;
        input [31:0] pc;
        input [31:0] expected;
        begin
            pc_out = pc;
            #1;
            checks = checks + 1;
            if (PCPlus4 !== expected) begin
                failures = failures + 1;
                $display("FAIL pc_out=%h -> PCPlus4=%h (want %h)",
                         pc, PCPlus4, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, Adder_for_PCPlus4_tb);

        checks = 0;
        failures = 0;
        pc_out = 32'd0;

        check(32'h00000000, 32'h00000004); // the first word of a program
        check(32'h00000004, 32'h00000008);
        check(32'h00001000, 32'h00001004); // an address one bit cannot carry
        check(32'hFFFFFFFC, 32'h00000000); // wraps at the top of the space
        check(32'h7FFFFFFC, 32'h80000000);

        if (failures == 0)
            $display("PCPlus4: %0d check(s) passed", checks);
        else begin
            $display("PCPlus4: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d PCPlus4 check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
