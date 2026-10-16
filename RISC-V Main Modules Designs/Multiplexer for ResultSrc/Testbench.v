`timescale 1ns / 1ps
// Self-checking testbench for the write-back multiplexer.
//
// What it replaces asserted nothing: four 1-bit values toggling into 32-bit
// inputs and $finish after 10 ns, with no expected value in the file.
//
// Two properties are checked. Every one of the three real selects has to
// deliver its own value - the three inputs are given distinct constants, so a
// swapped arm cannot pass - and `11` is not a select this design has, so it
// must leave the output unknown instead of substituting a zero that looks like
// a result. The original returned a defined 0 there.
//
// A real select follows the unknown one, so a mux that holds on to what it
// last produced fails as well.

module MUX_for_ResultSrc_tb;
    reg  [31:0] ALUResult, RD, PCPlus4;
    reg  [1:0]  ResultSrc;
    wire [31:0] Result;

    integer checks;
    integer failures;

    MUX_for_ResultSrc uut (
        .ALUResult(ALUResult),
        .RD(RD),
        .PCPlus4(PCPlus4),
        .ResultSrc(ResultSrc),
        .Result(Result)
    );

    task check;
        input [1:0]  select;
        input [31:0] expected;
        begin
            ResultSrc = select;
            #1;
            checks = checks + 1;
            if (Result !== expected) begin
                failures = failures + 1;
                $display("FAIL ResultSrc=%b ALUResult=%h RD=%h PCPlus4=%h -> Result=%h (want %h)",
                         select, ALUResult, RD, PCPlus4, Result, expected);
            end
        end
    endtask

    task check_unknown;
        input [1:0] select;
        begin
            ResultSrc = select;
            #1;
            checks = checks + 1;
            if (Result !== 32'bx) begin
                failures = failures + 1;
                $display("FAIL ResultSrc=%b is not a source: Result=%h (want x)",
                         select, Result);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, MUX_for_ResultSrc_tb);

        checks = 0;
        failures = 0;
        ALUResult = 32'h11111111;
        RD        = 32'h22222222;
        PCPlus4   = 32'h33333333;
        ResultSrc = 2'b00;

        check(2'b00, 32'h11111111); // an arithmetic result
        check(2'b01, 32'h22222222); // a value loaded from memory
        check(2'b10, 32'h33333333); // the return address of a jal
        check_unknown(2'b11);
        check(2'b00, 32'h11111111); // a real select after the unknown one

        if (failures == 0)
            $display("ResultSrc mux: %0d check(s) passed", checks);
        else begin
            $display("ResultSrc mux: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d ResultSrc mux check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
