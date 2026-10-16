`timescale 1ns / 1ps
// 32-bit ALU of the single-cycle processor.
//
// The control value is the 3-bit one the ALU decoder produces:
//
//   000 add                       011 or
//   001 sub                       100 slt (signed)
//   010 and                       101 branch (subtract, so `zero` means equal)
//
// Two properties are deliberate, and the rest of the CPU relies on them:
//
//  * `zero` follows the *result*: it is high exactly when ALUResult is zero.
//    That defines it for every operation, and a branch - which selects 101,
//    i.e. subtraction - reads it as "the operands are equal". Tying `zero` to
//    one operation instead leaves it undefined for all the others, and a
//    branch can then never be taken.
//  * the `case` is total: every arm assigns ALUResult, the unused control
//    values drive x, and `zero` is derived outside the case. An arm that
//    assigns only one of the two outputs makes the other one latch, because
//    this is combinational logic and nothing holds it.
//
// `slt` must be a *signed* comparison. `SrcA < SrcB` on two 32-bit vectors is
// unsigned in Verilog - that is `sltu`, a different RISC-V instruction - so
// both operands are cast with $signed().
//
// The assignments are blocking. This is an `always @(*)` block, so `=` is the
// correct operator; with `<=` the order of evaluation within the block is not
// what the code reads like.

module ALU(
    input  [31:0] SrcA, SrcB,
    input  [2:0]  ALUControl,
    output        zero,
    output reg [31:0] ALUResult
);
    always @(*) begin
        case (ALUControl)
            3'b000:  ALUResult = SrcA + SrcB;   // add
            3'b001:  ALUResult = SrcA - SrcB;   // sub
            3'b010:  ALUResult = SrcA & SrcB;   // and
            3'b011:  ALUResult = SrcA | SrcB;   // or
            3'b100:  ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0; // slt
            3'b101:  ALUResult = SrcA - SrcB;   // branch: subtract
            default: ALUResult = 32'bx;         // no such operation
        endcase
    end

    assign zero = (ALUResult == 32'd0);
endmodule
