`timescale 1ns / 1ps
// Self-checking testbench for the branch and jump target adder.
//
// What it replaces asserted nothing: two 1-bit registers toggled at different
// periods and $finish after 10 ns. With one-bit ports this adder could only
// ever produce 0, 1 or 2 - a branch target is a 32-bit address.

module Adder_for_PCTarget_tb;
    reg  [31:0] pc_out, ImmExt;
    wire [31:0] PCTarget;

    integer checks;
    integer failures;

    Adder_for_PCTarget uut (
        .pc_out(pc_out),
        .ImmExt(ImmExt),
        .PCTarget(PCTarget)
    );

    // Apply one (PC, immediate) pair and compare the target.
    task check;
        input [31:0] pc, imm;
        input [31:0] expected;
        begin
            pc_out = pc; ImmExt = imm;
            #1;
            checks = checks + 1;
            if (PCTarget !== expected) begin
                failures = failures + 1;
                $display("FAIL pc_out=%h ImmExt=%h -> PCTarget=%h (want %h)",
                         pc, imm, PCTarget, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, Adder_for_PCTarget_tb);

        checks = 0;
        failures = 0;
        pc_out = 32'd0; ImmExt = 32'd0;

        check(32'h00001000, 32'h00000010, 32'h00001010); // a forward branch
        check(32'h00001000, 32'hFFFFFFFC, 32'h00000FFC); // and a backward one
        check(32'h00000000, 32'hFFFFFFF8, 32'hFFFFFFF8); // the PC alone
        check(32'h00000010, 32'h00000000, 32'h00000010); // the immediate alone
        check(32'h80000000, 32'h80000000, 32'h00000000); // wraps at 2^32

        if (failures == 0)
            $display("PCTarget: %0d check(s) passed", checks);
        else begin
            $display("PCTarget: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d PCTarget check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
