`timescale 1ns / 1ps
// Self-checking testbench for the PC source multiplexer.
//
// What it replaces asserted nothing: three 1-bit registers toggled and
// $finish. The ports were one bit wide as well, so the mux that picks the
// address of the next instruction could only ever produce 0 or 1 - which is
// the defect the values below are chosen to expose.
//
// The two inputs are deliberately far apart and the same pair is used with the
// select flipped, so a mux that ignores the select, or truncates an input,
// fails a row instead of passing by luck.

module MUX_for_PCSrc_tb;
    reg  [31:0] PCPlus4, PCTarget;
    reg         PCSrc;
    wire [31:0] PCNext;

    integer checks;
    integer failures;

    MUX_for_PCSrc uut (
        .PCPlus4(PCPlus4),
        .PCTarget(PCTarget),
        .PCSrc(PCSrc),
        .PCNext(PCNext)
    );

    task check;
        input [31:0] plus4, target;
        input        select;
        input [31:0] expected;
        begin
            PCPlus4 = plus4; PCTarget = target; PCSrc = select;
            #1;
            checks = checks + 1;
            if (PCNext !== expected) begin
                failures = failures + 1;
                $display("FAIL PCSrc=%b PCPlus4=%h PCTarget=%h -> PCNext=%h (want %h)",
                         select, plus4, target, PCNext, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, MUX_for_PCSrc_tb);

        checks = 0;
        failures = 0;
        PCPlus4 = 32'd0; PCTarget = 32'd0; PCSrc = 1'b0;

        check(32'h00000004, 32'h00001000, 1'b0, 32'h00000004); // sequential
        check(32'h00000004, 32'h00001000, 1'b1, 32'h00001000); // branch taken
        check(32'hFFFFFFFC, 32'h00000008, 1'b0, 32'hFFFFFFFC);
        check(32'hFFFFFFFC, 32'h00000008, 1'b1, 32'h00000008);
        check(32'h00000000, 32'h80000000, 1'b1, 32'h80000000); // all 32 bits

        if (failures == 0)
            $display("PCSrc mux: %0d check(s) passed", checks);
        else begin
            $display("PCSrc mux: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d PCSrc mux check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
