`timescale 1ns / 1ps

// Design of Adder for PC Target

module Adder_for_PCTarget(
input [31:0] pc_out, ImmExt,
output [31:0] PCTarget
    );

    assign PCTarget = pc_out + ImmExt;

endmodule
