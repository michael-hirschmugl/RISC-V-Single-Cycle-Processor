`timescale 1ns / 1ps
// Main control decoder of the single-cycle processor: one arm per instruction
// form this design implements, every output assigned in every arm.
//
//   op        form            note
//   0000011   lw              address = rs1 + I-imm, write-back from memory
//   0100011   sw              address = rs1 + S-imm, no write-back
//   1100011   beq             conditional: PCSrc = branch & zero | jump
//   0010011   I-type ALU      rd = rs1 op I-imm
//   0110011   R-type ALU      rd = rs1 op rs2
//   1101111   jal             rd = PC+4, PC = PC + J-imm
//
// Two conventions come from the ALU and this decoder has to keep them: a
// branch selects ALUop 01, which the ALU decoder turns into the subtract that
// makes `zero` mean "operands equal", and `zero` is a function of the result,
// so `branch & zero` resolves for every operation.
//
// Conventions of this module:
//
//  * blocking assigns in the combinational always block (the original used
//    `<=` here, which is what Verilog calls COMBDLY and what makes the order
//    of the block not what the code reads like),
//  * `default` drives x, so an opcode this design does not implement is a
//    visible unknown instead of silently turning into something else - the
//    original `default` returned all zeros, i.e. "an ALU instruction that
//    writes nothing", for any garbage opcode.
//
// ImmSrc selects the immediate shape in Extend: 00 I, 01 S, 10 B, 11 J.
// ResultSrc selects the write-back source: 00 ALUResult, 01 ReadData, 10 PCPlus4.
// ALUop: 00 add (address), 01 subtract (branch), 10 the funct3/alt decode.
//
// Not implemented, and therefore in `default`: jalr (its PC comes from the ALU
// result, which the PC mux cannot select yet), lui, auipc, and the fused
// multiply form of the M extension.

module MainDecoder(
    input [6:0] op,
    output reg RegWrite,
    output reg MemWrite,
    output reg Branch,
    output reg ALUSrc,
    output reg [1:0] ALUop,
    output reg [1:0] ImmSrc,
    output reg [1:0] ResultSrc,
    output reg jump
);
    always @(*) begin
        case (op)
            7'b0000011: begin // lw
                RegWrite = 1'b1; MemWrite = 1'b0; Branch = 1'b0; ALUSrc = 1'b1;
                ALUop = 2'b00;   ImmSrc = 2'b00;  ResultSrc = 2'b01; jump = 1'b0;
            end
            7'b0100011: begin // sw
                RegWrite = 1'b0; MemWrite = 1'b1; Branch = 1'b0; ALUSrc = 1'b1;
                ALUop = 2'b00;   ImmSrc = 2'b01;  ResultSrc = 2'b00; jump = 1'b0;
            end
            7'b1100011: begin // beq
                RegWrite = 1'b0; MemWrite = 1'b0; Branch = 1'b1; ALUSrc = 1'b0;
                ALUop = 2'b01;   ImmSrc = 2'b10;  ResultSrc = 2'b00; jump = 1'b0;
            end
            7'b0010011: begin // I-type ALU
                RegWrite = 1'b1; MemWrite = 1'b0; Branch = 1'b0; ALUSrc = 1'b1;
                ALUop = 2'b10;   ImmSrc = 2'b00;  ResultSrc = 2'b00; jump = 1'b0;
            end
            7'b0110011: begin // R-type ALU
                RegWrite = 1'b1; MemWrite = 1'b0; Branch = 1'b0; ALUSrc = 1'b0;
                ALUop = 2'b10;   ImmSrc = 2'b00;  ResultSrc = 2'b00; jump = 1'b0;
            end
            7'b1101111: begin // jal
                RegWrite = 1'b1; MemWrite = 1'b0; Branch = 1'b0; ALUSrc = 1'b0;
                ALUop = 2'b00;   ImmSrc = 2'b11;  ResultSrc = 2'b10; jump = 1'b1;
            end
            default: begin // no such instruction: make it visible
                RegWrite = 1'bx; MemWrite = 1'bx; Branch = 1'bx; ALUSrc = 1'bx;
                ALUop = 2'bxx;   ImmSrc = 2'bxx;  ResultSrc = 2'bxx; jump = 1'bx;
            end
        endcase
    end
endmodule
