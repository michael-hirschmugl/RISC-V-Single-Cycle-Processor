`timescale 1ns / 1ps
// Self-checking testbench for the immediate generator.
//
// What it replaces asserted nothing: two 25-bit patterns were driven into
// `instruction[31:7]` once per ImmSrc and the simulation ended. Nothing was
// compared, so a wrong bit in any of the four formats would have passed.
//
// The instruction words below were assembled, not hand-written - the RISC-V
// toolchain in this image produced them and `riscv-none-elf-objdump` printed
// them - and every row names the immediate the ISA defines for it. Each format
// gets a forward value, a backward value and a value whose sign has to reach
// bit 31.

module Extend_tb;
    reg  [31:0] instruction;
    reg  [1:0]  ImmSrc;
    wire [31:0] ImmExt;

    integer checks;
    integer failures;

    Extend uut (
        .instruction(instruction[31:7]),
        .ImmSrc(ImmSrc),
        .ImmExt(ImmExt)
    );

    task check;
        input [1:0]  src;
        input [31:0] word;
        input [31:0] expected;
        begin
            instruction = word; ImmSrc = src;
            #1;
            checks = checks + 1;
            if (ImmExt !== expected) begin
                failures = failures + 1;
                $display("FAIL ImmSrc=%b instruction=%h -> ImmExt=%h (want %h)",
                         src, word, ImmExt, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, Extend_tb);

        checks = 0;
        failures = 0;
        instruction = 32'd0;
        ImmSrc = 2'b00;

        // I-type: instruction[31:20], sign-extended
        check(2'b00, 32'h00500093, 32'h00000005); // addi x1, x0, 5
        check(2'b00, 32'hFFF00093, 32'hFFFFFFFF); // addi x1, x0, -1
        check(2'b00, 32'h80000093, 32'hFFFFF800); // addi x1, x0, -2048
        check(2'b00, 32'h0040A283, 32'h00000004); // lw x5, 4(x1)

        // S-type: the immediate is split across instruction[31:25] and
        // instruction[11:7]
        check(2'b01, 32'h00302023, 32'h00000000); // sw x3, 0(x0)
        check(2'b01, 32'h00302423, 32'h00000008); // sw x3, 8(x0)
        check(2'b01, 32'hFE302E23, 32'hFFFFFFFC); // sw x3, -4(x0)

        // B-type: four fields, and the lowest bit is zero by encoding
        check(2'b10, 32'h00208663, 32'h0000000C); // beq x1, x2, +12
        check(2'b10, 32'hFE208CE3, 32'hFFFFFFF8); // beq x1, x2, -8

        // J-type: the same shape with different fields
        check(2'b11, 32'h00C000EF, 32'h0000000C); // jal x1, +12
        check(2'b11, 32'hFF9FF0EF, 32'hFFFFFFF8); // jal x1, -8

        if (failures == 0)
            $display("Extend: %0d check(s) passed", checks);
        else begin
            $display("Extend: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Extend check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
