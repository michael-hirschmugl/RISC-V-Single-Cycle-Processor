// Design Of Multiplexer for PCSrc Select Line
`timescale 1ns / 1ps

module MUX_for_PCSrc(
input [31:0] PCPlus4, PCTarget,
input PCSrc,
output [31:0] PCNext
    );

    assign PCNext = PCSrc?PCTarget:PCPlus4;
endmodule
