`timescale 1ns / 1ps
// The control unit of the single-cycle processor: the two decoders plus the one
// piece of logic that combines them.
//
//   PCSrc = branch & zero | jump
//
// `zero` comes from the ALU, and it only means "the operands are equal" because
// a branch selects the subtract control (101) in the ALU decoder. `jump` is
// unconditional: jal does not wait for a comparison.
//
// Ports follow the instruction: `op` and `funct3` from the instruction word,
// `alt` = instruction[30] (the add/sub bit - one bit, not the whole funct7
// field), `zero` from the ALU. The outputs are the datapath's control bundle,
// with ResultSrc selecting the write-back source (00 ALUResult, 01 ReadData,
// 10 PCPlus4).
//
// The same module exists inside "Data Path/Design.v" (the datapath carries a
// copy of every module it instantiates); keep the two in step.

module ALUControl(
    input [6:0] op,
    input [2:0] funct3,
    input alt,
    input zero,
    output wire PCSrc,
    output wire jump,
    output wire ALUSrc,
    output wire RegWrite,
    output wire MemWrite,
    output wire branch,
    output wire [1:0] ResultSrc,
    output wire [1:0] ImmSrc,
    output wire [2:0] ALUControl
);
    wire [1:0] ALUop;
    MainDecoder md(
        .op(op),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .Branch(branch),
        .ALUSrc(ALUSrc),
        .ALUop(ALUop),
        .ImmSrc(ImmSrc),
        .ResultSrc(ResultSrc),
        .jump(jump)
    );
    ALUDecoder ad(
        .funct3(funct3),
        .alt(alt),
        .ALUop(ALUop),
        .ALUControl(ALUControl)
    );

    // A conditional branch needs both "this is a branch" and a zero result;
    // jal jumps unconditionally, which is what `jump` contributes here.
    assign PCSrc = (branch & zero) | jump;
endmodule
