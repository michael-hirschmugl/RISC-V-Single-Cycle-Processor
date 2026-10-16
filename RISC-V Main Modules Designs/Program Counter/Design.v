`timescale 1ns / 1ps

// The Program Counter (PC) Design

module program_counter(
input clk, reset,
input [31:0] pc_in, // Input Port
output reg [31:0] pc_out // Output Port
    );

    // pc_in is the *next* PC, i.e. the output of the PC mux: PCPlus4 for a
    // sequential instruction, PCTarget for a taken branch or a jal. A cycle
    // therefore loads that value directly.
    //
    // The original computed pc_in + 4. With pc_in already being PC + 4 that
    // made the PC advance by eight, i.e. every second instruction, and the
    // branch target never reached the PC at all.
    //
    // Reset starts the fetch at address 0, the first word of the program the
    // instruction memory holds; the original copied pc_in, which is the very
    // value the datapath derives from pc_out and is therefore not a reset
    // value at all.
    always@(posedge clk)
    if (reset)
        pc_out<=32'd0;
    else
        pc_out<=pc_in;
endmodule
