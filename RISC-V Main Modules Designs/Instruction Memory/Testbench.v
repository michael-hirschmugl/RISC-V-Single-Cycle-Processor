`timescale 1ns / 1ps
// Self-checking testbench for the instruction memory.
//
// What it replaces asserted nothing: four addresses were set and the run
// finished. The words it read are the design - this ROM *is* the program - so
// they are compared here, together with the address decoding: the read is word
// addressed (`A[31:2]`), so the two low bits of an address must not select
// another word.
//
// One word changed. The store used to be 32'h00300023, which the assembler
// decodes as `sb x3, 0(x0)` and not as the `sw x3, 0(x0)` its comment claimed.
// The control unit decodes a store by opcode and ignores funct3, so the wrong
// word behaved exactly like the right one - which is why it went unnoticed.
// It is 32'h00302023 now, and the load that reads the stored word back is the
// fifth word, so the datapath test has something to observe.

module Instruction_Memory_tb;
    reg  [31:0] A;
    wire [31:0] RD;

    integer checks;
    integer failures;

    Instruction_Memory uut (
        .A(A),
        .RD(RD)
    );

    task check;
        input [31:0] address;
        input [31:0] expected;
        begin
            A = address;
            #1;
            checks = checks + 1;
            if (RD !== expected) begin
                failures = failures + 1;
                $display("FAIL A=%h -> RD=%h (want %h)", address, RD, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, Instruction_Memory_tb);

        checks = 0;
        failures = 0;
        A = 32'd0;

        check(32'h00000000, 32'h00500093); // li x1, 5
        check(32'h00000004, 32'h00A00113); // li x2, 10
        check(32'h00000008, 32'h002081B3); // add x3, x1, x2
        check(32'h0000000C, 32'h00302023); // sw x3, 0(x0)
        check(32'h00000010, 32'h00002203); // lw x4, 0(x0)

        // Word addressing: the low two bits are not part of the index.
        check(32'h00000001, 32'h00500093);
        check(32'h0000000F, 32'h00302023);
        check(32'h00000012, 32'h00002203);

        // And back to the first word - a read path that latched a value would
        // fail here rather than anywhere above.
        check(32'h00000000, 32'h00500093);

        if (failures == 0)
            $display("Instruction Memory: %0d check(s) passed", checks);
        else begin
            $display("Instruction Memory: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Instruction Memory check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
