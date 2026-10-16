`timescale 1ns / 1ps

// Design of Register File

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
    
    // The read path used to test `A1 == 1`, which made x1 the only readable
    // register: every other read answered 0. The rule is "x0 reads as zero",
    // so the test belongs on zero.
    always@(*) begin
        RD1 = (A1 != 5'd0)? register_file[A1]:32'd0;
        RD2 = (A2 != 5'd0)? register_file[A2]:32'd0;
    end
    
endmodule
