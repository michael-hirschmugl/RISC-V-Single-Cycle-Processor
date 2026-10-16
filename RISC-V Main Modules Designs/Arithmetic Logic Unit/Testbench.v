`timescale 1ns / 1ps
// Self-checking testbench for the ALU.
//
// It drives the design at its real width and compares *both* outputs against
// an expected value on every step. A mismatch prints a FAIL line and is
// counted; at the end the run calls $fatal, which turns into a non-zero exit
// code - so a wrong answer is a failed run and not a quiet green one.
//
// What it replaces: this bench used to declare `reg [1:0] A, B` and wire them
// into ports named .A/.B, which the ALU does not have (it takes 32-bit
// SrcA/SrcB). It could not even be compiled, and it asserted nothing even if
// it had been: no expected value appeared anywhere in it.
//
// Every ALUControl value is exercised, including the two that select no
// operation. That is the point of the list: the `case` in the design being
// total, and `zero` following the result, are the properties a branch depends
// on.

module ALU_tb;
    reg  [31:0] SrcA, SrcB;
    reg  [2:0]  ALUControl;
    wire [31:0] ALUResult;
    wire        zero;

    integer checks;
    integer failures;

    ALU uut (
        .SrcA(SrcA),
        .SrcB(SrcB),
        .ALUControl(ALUControl),
        .zero(zero),
        .ALUResult(ALUResult)
    );

    // Apply one step and compare both outputs. `!==` rather than `!=` on
    // purpose: an output that is still x or z is a mismatch too, and `!=`
    // would call that equal - which is exactly how a latching `zero` stays
    // invisible.
    task check;
        input [2:0]  control;
        input [31:0] a, b;
        input [31:0] expected_result;
        input        expected_zero;
        begin
            SrcA = a; SrcB = b; ALUControl = control;
            #1;
            checks = checks + 1;
            if (ALUResult !== expected_result || zero !== expected_zero) begin
                failures = failures + 1;
                $display("FAIL ALUControl=%b SrcA=%h SrcB=%h -> ALUResult=%h (want %h), zero=%b (want %b)",
                         control, a, b, ALUResult, expected_result, zero, expected_zero);
            end
        end
    endtask

    // The two control values that select no operation must drive x, not the
    // value of the step before.
    task check_unknown;
        input [2:0] control;
        begin
            ALUControl = control;
            #1;
            checks = checks + 1;
            if (ALUResult !== 32'bx || zero !== 1'bx) begin
                failures = failures + 1;
                $display("FAIL ALUControl=%b selects no operation: ALUResult=%h (want x), zero=%b (want x)",
                         control, ALUResult, zero);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, ALU_tb);

        checks = 0;
        failures = 0;
        SrcA = 32'd0; SrcB = 32'd0; ALUControl = 3'b000;

        // Consecutive steps mostly differ in both outputs, so a design that
        // latches a value instead of computing it fails on the step *after*
        // the one it latched - not only on the step itself. The two rows that
        // legitimately repeat a value are the second and third slt case (both
        // produce 0); the unknown-value checks at the end cover a latch
        // directly.
        check(3'b000, 32'h00000001, 32'h00000002, 32'h00000003, 1'b0); // add
        check(3'b001, 32'h00000005, 32'h00000003, 32'h00000002, 1'b0); // sub
        check(3'b010, 32'hF0F0F0F0, 32'h0FF00FF0, 32'h00F000F0, 1'b0); // and
        check(3'b011, 32'h00000001, 32'h00000002, 32'h00000003, 1'b0); // or

        // slt is signed: -1 < 1 is true, and 1 < -1 is false. An unsigned
        // compare - `SrcA < SrcB` without the casts - answers the other way
        // round and is `sltu`.
        check(3'b100, 32'hFFFFFFFF, 32'h00000001, 32'h00000001, 1'b0);
        // A false slt produces 0, and `zero` is a function of the result, so
        // it is 1 here. That is the convention, not a slip: only a branch
        // reads `zero`, and a branch uses control 101, never slt.
        check(3'b100, 32'h00000001, 32'hFFFFFFFF, 32'h00000000, 1'b1);
        check(3'b100, 32'h00000005, 32'h00000005, 32'h00000000, 1'b1); // slt, equal
        check(3'b100, 32'h80000000, 32'h00000001, 32'h00000001, 1'b0); // most negative < 1

        // Branch: control 101 subtracts, so `zero` means the operands are
        // equal. This is what makes a PCSrc resolvable at all.
        check(3'b101, 32'h00000007, 32'h00000007, 32'h00000000, 1'b1);
        check(3'b101, 32'h00000007, 32'h00000008, 32'hFFFFFFFF, 1'b0);

        // zero is a function of the result, not of the operation: it is set
        // by every operation that happens to produce zero.
        check(3'b000, 32'h00000000, 32'h00000000, 32'h00000000, 1'b1); // add
        check(3'b001, 32'h00000008, 32'h00000007, 32'h00000001, 1'b0); // sub
        check(3'b010, 32'hFFFFFFFF, 32'h00000000, 32'h00000000, 1'b1); // and
        check(3'b011, 32'h11110000, 32'h00001111, 32'h11111111, 1'b0); // or

        // No operation selected - and a real operation right after, which
        // fails if the unknown value is held on to.
        check_unknown(3'b110);
        check_unknown(3'b111);
        check(3'b000, 32'h00000001, 32'h00000001, 32'h00000002, 1'b0);

        if (failures == 0)
            $display("ALU: %0d check(s) passed", checks);
        else begin
            $display("ALU: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d ALU check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
