`timescale 1ns / 1ps
// ALU control decoder: turns ALUop plus the instruction's funct3 into the
// 3-bit control value the ALU takes.
//
//   ALUop  meaning                    result
//   00     address for lw/sw          000 add
//   01     branch                     101 subtract, so `zero` means equal
//   10     R-type / I-type ALU        funct3 picks it, see below
//   11     not used by this decoder   xxx
//
//   funct3  alt=0       alt=1      instruction
//   000     000 add     001 sub    add/addi, sub
//   010     100 slt     100 slt    slt/slti - signed (the ALU's 100)
//   110     011 or      011 or     or/ori
//   111     010 and     010 and    and/andi
//   others  xxx                    shifts (001/101), xor (100), sltu (011)
//
// `alt` is instruction[30]. It is *one* bit and it is not the funct7 field:
// the original compared `{funct7, funct3, op}` - 1 + 3 + 7 = 11 bits - against
// 10-bit labels, so every label was shifted by one position and the case
// actually compared funct3 against the opcode. Decoding on funct3 with one
// alt bit for add/sub is what the ISA needs; into it, `funct7` was a name that
// hid the width error. (There is no shifter and no unsigned compare in the
// ALU, so those are deliberately *not* mapped - they drive x instead.)
//
// Two further properties are deliberate: the case on ALUop is total (the
// original had no arm for ALUop 11 and latched ALUControl), and the assigns
// are blocking, like everywhere else in this design's combinational logic.

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
