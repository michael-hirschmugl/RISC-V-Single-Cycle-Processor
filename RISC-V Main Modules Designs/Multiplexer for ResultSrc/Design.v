`timescale 1ns / 1ps

// Design of Multiplexer for ResultSrc

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
