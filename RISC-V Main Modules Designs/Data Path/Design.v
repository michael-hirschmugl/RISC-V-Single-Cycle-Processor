`timescale 1ns / 1ps

// Logic Blocks of RISC-v Processor

///////////////////Logic for MUX for PCSrc/////////////////////////////////////////////////////////////////////////////////////////////////

module MUX_for_PCSrc(
input [31:0] PCPlus4, PCTarget,
input PCSrc,
output [31:0] PCNext
    );
    
    assign PCNext = PCSrc?PCTarget:PCPlus4;
endmodule

/////////////////PC Logic//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module program_counter(
input clk, reset, 
input [31:0] pc_in,
output reg [31:0] pc_out
    );
    // pc_in is the *next* PC from the PC mux (PCPlus4 or PCTarget), so a cycle
    // loads it directly; the original computed pc_in + 4, which advances the
    // PC by eight once pc_in is already PC + 4, and reset copied pc_in instead
    // of starting the fetch at the program's first word.
    always@(posedge clk)
    if (reset)
        pc_out<=32'd0;
    else
        pc_out<=pc_in;    
endmodule
///////////////Logic of Adder for PCPlus4////////////////////////////////////////////////////////////////////////////////////////////////////

module Adder_for_PCPlus4(
input [31:0] pc_out,
output [31:0] PCPlus4
    );
    
    assign PCPlus4 = pc_out + 4;
endmodule

//////////////////Logic of Adder for PCTarget/////////////////////////////////////////////////////////////////////////////////////////////
module Adder_for_PCTarget(
input [31:0] pc_out, ImmExt,
output [31:0] PCTarget
    );
    
    assign PCTarget = pc_out + ImmExt;

endmodule

///////////////////////Logic for Instruction Memory////////////////////////////////////////
module Instruction_Memory(
input [31:0]A, // Address input
output reg [31:0]RD // Instruction output
    );
    // Instruction memory array (ROM)
    reg [31:0] mem[63:0];
    
    // Initialize the ROM with the program instructions
    initial begin
        mem[0] = 32'h00500093;  // li x1, 5 (addi x1, x0, 5)
        mem[1] = 32'h00A00113;  // li x2, 10 (addi x2, x0, 10)
        mem[2] = 32'h002081B3;  // add x3, x1, x2
        mem[3] = 32'h00302023;  // sw x3, 0(x0)
        mem[4] = 32'h00002203;  // lw x4, 0(x0)
    end

    // Read operation
    always @(*) begin
        RD = mem[A[31:2]];  // Address decoding (assuming word addressing)
    end
endmodule

////////////////////////// Logic for Register File//////////////////////////////////////////

module RegFile(
input WE3, clk,
input [4:0] A1,
input [4:0] A2,
input [4:0] A3,
input [31:0] WD3,
output reg [31:0] RD1, 
output reg [31:0] RD2
    );
    
    reg [31:0] register_file[31:0];
    
    // x0 is hard-wired to zero, so a write to it is dropped.
    always@(posedge clk)
    if (WE3 && A3 != 5'd0)
        register_file[A3] <= WD3;
    
    always@(*) begin
        RD1 = (A1 != 5'd0)? register_file[A1]:32'd0;
        RD2 = (A2 != 5'd0)? register_file[A2]:32'd0;
    end
    
endmodule

/////////////////Logic of MUX for ALUSrc/////////////////////////////////////////////////////

module MUX_for_ALUSrc(
input [31:0] RD2, ImmExt,
input ALUSrc,
output [31:0] SrcB
    );
    assign SrcB=ALUSrc?ImmExt:RD2;
endmodule

//////////////////Logic of Extend///////////////////////////////////////////////////////////

module Extend(
input [31:7]instruction, 
input [1:0]ImmSrc,
output reg [31:0]ImmExt
    );
    
    always@(*) begin
    case(ImmSrc)
        2'b00: ImmExt = {{20{instruction[31]}}, instruction[31:20]};// I
        2'b01: ImmExt = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};// S
        2'b10: ImmExt = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};// B
        2'b11: ImmExt = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};// J
    endcase    
    end    
endmodule

////////////////////////// Logic For ALU/////////////////////////////////////////////////////
module ALU(
    input [31:0] SrcA, SrcB,
    input [2:0] ALUControl,
    output        zero,
    output reg [31:0] ALUResult
);
    // Combinational logic: blocking assignments, and the case is total - every
    // arm assigns ALUResult, so nothing latches.
    always @(*) begin
        case (ALUControl)
            3'b000:  ALUResult = SrcA + SrcB;   // Addition
            3'b001:  ALUResult = SrcA - SrcB;   // Subtraction
            3'b010:  ALUResult = SrcA & SrcB;   // AND operation
            3'b011:  ALUResult = SrcA | SrcB;   // OR operation
            3'b100:  ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0; // SLT, signed
            3'b101:  ALUResult = SrcA - SrcB;   // BEQ: subtract, so `zero` means equal
            default: ALUResult = 32'bx;         // DONT CARE
        endcase
    end

    // `zero` follows the result, not the operation: that defines it for every
    // operation and is what makes a branch resolvable at all.
    assign zero = (ALUResult == 32'd0);
endmodule


/////////////////////////Logic for ALU Decoder//////////////////////////////////////////

// Copy of the module in "ALU Decoder/Design.v", kept in step with it: this is
// the one the controller below instantiates. The 3-bit values are the ALU's
// (100 slt signed, 101 branch/subtract), the case is total and the assigns are
// blocking.
module ALUDecoder(
    input [2:0] funct3,
    input       alt,
    input [1:0] ALUop,
    output reg [2:0] ALUControl
);
    always @(*) begin
        case (ALUop)
            2'b00: ALUControl = 3'b000; // add: address for lw/sw
            2'b01: ALUControl = 3'b101; // branch: subtract
            2'b10: begin
                case (funct3)
                    3'b000:  ALUControl = alt ? 3'b001 : 3'b000; // sub : add
                    3'b010:  ALUControl = 3'b100;                // slt, signed
                    3'b110:  ALUControl = 3'b011;                // or
                    3'b111:  ALUControl = 3'b010;                // and
                    default: ALUControl = 3'bxxx;                // shift, xor, sltu
                endcase
            end
            default: ALUControl = 3'bxxx; // ALUop 11 selects no operation
        endcase
    end
endmodule


/////////////////////Logic for Main Decoder////////////////////////////////////////////////////
// Copy of the module in "Main Decoder/Design.v", kept in step with it: this is
// the one the controller below instantiates. Six opcodes, every output assigned
// in every arm, blocking assigns, and `default` drives x so an unimplemented
// instruction cannot pass as a no-op.
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

//////////////////////////Logic for ALU Control///////////////////////////////////////////////////

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


/////////////////////Logic for Data Memory//////////////////////////////////////////////////////////
module Data_Memory(
input clk, WE, 
input [31:0]A,
input [31:0] WD,
output  [31:0]RD
    );
    reg [31:0] mem[63:0];
    
    assign RD = mem[A[31:2]];
    
    always @(posedge clk) begin
        if (WE) 
           mem[A[31:2]]<= WD;
    end
    
endmodule


//////////////////Logic for MUX for ResultSrc////////////////////////////////////////////////

module MUX_for_ResultSrc(
input [31:0] ALUResult,
input [31:0] RD,
input [31:0] PCPlus4,
input [1:0] ResultSrc,
output reg [31:0] Result
    );
    always @(*) begin
        case (ResultSrc)
            2'b00: Result = ALUResult; // Select ALUResult
            2'b01: Result = RD;        // Select RD
            2'b10: Result = PCPlus4;   // Select PCPlus4
            default: Result = 32'bx;   // No such source: unknown rather than a plausible zero
        endcase
    end
endmodule

/////////////////////////// Logic for Datapath//////////////////////////////////////////////////////////
module Data_Path(
    input clk, reset,
    input PCSrc, jump, ALUSrc, RegWrite,
    input MemWrite,
    input [1:0] ResultSrc,
    input [2:0] ALUControl,
    input [1:0] ImmSrc,
    input [31:0] instruction,
    output zero,
    output [31:0] PC,
    output [31:0] WriteData,
    output [31:0] ReadData,
    output [31:0] ALUResult 
);
    wire [31:0] PCNext, PCPlus4, ImmExt, PCTarget, Result, SrcA, SrcB;
    wire [31:0] PC_out;

    // PC Logic flow
    program_counter pc(clk, reset, PCNext, PC_out);
    Adder_for_PCPlus4 a1(PC_out, PCPlus4);
    Adder_for_PCTarget a2(PC_out, ImmExt, PCTarget);
    // jump arrives separately as well as folded into PCSrc by the controller;
    // OR-ing it in is a no-op with that controller and is what keeps the
    // datapath working with one that hands over `branch & zero` alone.
    MUX_for_PCSrc m1(PCPlus4, PCTarget, PCSrc | jump, PCNext);
    
    // Register File Logic Flow
    RegFile rf(RegWrite, clk, instruction[19:15], instruction[24:20], instruction[11:7], Result, SrcA, WriteData);
    Extend e(instruction[31:7], ImmSrc, ImmExt);
    
    // ALU Logic
    MUX_for_ALUSrc m2(WriteData, ImmExt, ALUSrc, SrcB);
    ALU alu(SrcA, SrcB, ALUControl, zero, ALUResult);
    
    // Data Memory Logic
    Data_Memory dm(clk, MemWrite, ALUResult, WriteData, ReadData);
    
    // MUX for ResultSrc
    MUX_for_ResultSrc m3(ALUResult, ReadData, PCPlus4, ResultSrc, Result);
    
    // Output Assignments
    assign PC = PC_out;
endmodule
