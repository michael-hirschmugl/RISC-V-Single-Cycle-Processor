`timescale 1ns / 1ps
// Self-checking testbench for the data memory.
//
// What it replaces wrote one word and never read it back or compared it: the
// stimulus was there and the check was not.
//
// Three properties: a stored word comes back, a second word does not disturb
// the first, and a write with WE low does not happen. The read is
// asynchronous (`assign RD = mem[A[31:2]]`) and the address is word addressed,
// so 8, 9, 10 and 11 name one word - which is what the check on 0x0B pins.

module Data_Memory_tb;
    reg  clk, WE;
    reg  [31:0] A, WD;
    wire [31:0] RD;

    integer checks;
    integer failures;

    Data_Memory uut (
        .clk(clk),
        .WE(WE),
        .A(A),
        .WD(WD),
        .RD(RD)
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

    task write_word;
        input [31:0] address, value;
        input        enable;
        begin
            A = address; WD = value; WE = enable;
            tick;
            WE = 1'b0;
        end
    endtask

    task check_word;
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
        $dumpvars(0, Data_Memory_tb);

        checks = 0;
        failures = 0;
        clk = 1'b0; WE = 1'b0; A = 32'd0; WD = 32'd0;

        // A stored word comes back.
        write_word(32'h00000000, 32'hABCDEFFF, 1'b1);
        check_word(32'h00000000, 32'hABCDEFFF);

        // A second word, without disturbing the first.
        write_word(32'h00000004, 32'h11223344, 1'b1);
        check_word(32'h00000004, 32'h11223344);
        check_word(32'h00000000, 32'hABCDEFFF);

        // A write with WE low does not happen.
        write_word(32'h00000000, 32'h99999999, 1'b0);
        check_word(32'h00000000, 32'hABCDEFFF);

        // Word addressing: 8, 9, 10 and 11 are the same word, and it is not
        // the one at address 0.
        write_word(32'h00000008, 32'hDEADBEEF, 1'b1);
        check_word(32'h00000008, 32'hDEADBEEF);
        check_word(32'h0000000B, 32'hDEADBEEF);
        check_word(32'h00000001, 32'hABCDEFFF);

        // And a read of the second word after all of it: a read path that
        // latched would fail here.
        check_word(32'h00000005, 32'h11223344);

        if (failures == 0)
            $display("Data Memory: %0d check(s) passed", checks);
        else begin
            $display("Data Memory: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Data Memory check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
