`timescale 1ns / 1ps

// Top level of the single-cycle RISC-V processor.
//
// The fifteen modules live in their own directories, one each; this is the
// root that assembles them into a machine. It instantiates the instruction
// memory, the control unit and the datapath - the three blocks the `Data
// Path` testbench used to wire around the datapath, now a module of the
// design rather than of the bench. All three are defined in `Data
// Path/Design.v`, which the build pulls in as a companion source: that file
// carries the copies of every module the datapath needs, and one directory
// is one compilation.
//
// The instruction memory is the ROM the repository ships, a fixed five-word
// program:
//
//     li   x1, 5        addi x1, x0, 5
//     li   x2, 10       addi x2, x0, 10
//     add  x3, x1, x2
//     sw   x3, 0(x0)
//     lw   x4, 0(x0)
//
// which is also what the differential test against Renode runs.
//
// The ROM holds no branch and no jump, so the `PCSrc` path - the one the
// ALU and the control unit were repaired for - is exercised through the
// `override` inputs: the bench feeds a probe instruction in place of the
// fetched word. That is a test hook, and it is the only one.

module CPU(
    input clk, reset,
    input override,
    input [31:0] instruction_override,
    output [31:0] instruction,
    output zero,
    output [31:0] PC,
    output [31:0] WriteData,
    output [31:0] ReadData,
    output [31:0] ALUResult
);
    wire [31:0] fetched;
    wire        PCSrc, jump, ALUSrc, RegWrite, MemWrite, branch;
    wire [1:0]  ResultSrc, ImmSrc;
    wire [2:0]  alu_control;

    assign instruction = override ? instruction_override : fetched;

    Instruction_Memory im (
        .A(PC),
        .RD(fetched)
    );

    ALUControl ctrl (
        .op(instruction[6:0]),
        .funct3(instruction[14:12]),
        .alt(instruction[30]),
        .zero(zero),
        .PCSrc(PCSrc),
        .jump(jump),
        .branch(branch),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .ImmSrc(ImmSrc),
        .ALUControl(alu_control)
    );

    Data_Path dp (
        .clk(clk),
        .reset(reset),
        .PCSrc(PCSrc),
        .jump(jump),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .ALUControl(alu_control),
        .ImmSrc(ImmSrc),
        .instruction(instruction),
        .zero(zero),
        .PC(PC),
        .WriteData(WriteData),
        .ReadData(ReadData),
        .ALUResult(ALUResult)
    );
endmodule
