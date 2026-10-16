`timescale 1ns / 1ps
// Self-checking testbench for the ALUSrc multiplexer.
//
// What it replaces asserted nothing: three 1-bit registers toggled at
// different periods and $finish after 10 ns. The ports were one bit wide as
// well, so the mux that chooses between a register operand and an immediate
// could only ever carry 0 or 1 - which is what the values below pin down.
//
// It also wrote its waveform to `dump.file`; the driver reports whichever
// file a bench produced, and this one now produces the usual `dump.vcd`.

module MUX_for_ALUSrc_tb;
    reg  [31:0] RD2, ImmExt;
    reg         ALUSrc;
    wire [31:0] SrcB;

    integer checks;
    integer failures;

    MUX_for_ALUSrc uut (
        .RD2(RD2),
        .ImmExt(ImmExt),
        .ALUSrc(ALUSrc),
        .SrcB(SrcB)
    );

    // Both inputs are held at distinctly recognisable constants, so a mux that
    // keeps the wrong operand - or truncates it - cannot pass by coincidence.
    task check;
        input [31:0] rd2, imm;
        input        select;
        input [31:0] expected;
        begin
            RD2 = rd2; ImmExt = imm; ALUSrc = select;
            #1;
            checks = checks + 1;
            if (SrcB !== expected) begin
                failures = failures + 1;
                $display("FAIL ALUSrc=%b RD2=%h ImmExt=%h -> SrcB=%h (want %h)",
                         select, rd2, imm, SrcB, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, MUX_for_ALUSrc_tb);

        checks = 0;
        failures = 0;
        RD2 = 32'd0; ImmExt = 32'd0; ALUSrc = 1'b0;

        check(32'h0000000A, 32'hFFFFFFF0, 1'b0, 32'h0000000A); // register operand
        check(32'h0000000A, 32'hFFFFFFF0, 1'b1, 32'hFFFFFFF0); // immediate operand
        check(32'hDEADBEEF, 32'h00000004, 1'b0, 32'hDEADBEEF);
        check(32'hDEADBEEF, 32'h00000004, 1'b1, 32'h00000004);
        check(32'h00000001, 32'h00000000, 1'b1, 32'h00000000); // both same size

        if (failures == 0)
            $display("ALU SrcB mux: %0d check(s) passed", checks);
        else begin
            $display("ALU SrcB mux: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d ALU SrcB mux check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
