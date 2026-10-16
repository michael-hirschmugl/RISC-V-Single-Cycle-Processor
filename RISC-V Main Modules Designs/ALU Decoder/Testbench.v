`timescale 1ns / 1ps
// Self-checking testbench for the ALU control decoder.
//
// The rows are the ALU's control values, so this file is also where the
// contract between the two modules is written down: a branch is control 101
// (subtract, which is what makes `zero` mean "operands equal") and slt is 100,
// the *signed* compare.
//
// What it replaces asserted nothing - and the design it drove decoded
// `{funct7, funct3, op}` (11 bits) against 10-bit labels, i.e. on a window
// shifted by one bit. A bench that cannot fail does not notice that.

module ALUDecoder_tb;
    reg  [2:0] funct3;
    reg        alt;
    reg  [1:0] ALUop;
    wire [2:0] ALUControl;

    integer checks;
    integer failures;

    ALUDecoder uut (
        .funct3(funct3),
        .alt(alt),
        .ALUop(ALUop),
        .ALUControl(ALUControl)
    );

    task check;
        input [2:0] funct3_in;
        input       alt_in;
        input [1:0] aluop_in;
        input [2:0] expected;
        begin
            funct3 = funct3_in; alt = alt_in; ALUop = aluop_in;
            #1;
            checks = checks + 1;
            if (ALUControl !== expected) begin
                failures = failures + 1;
                $display("FAIL ALUop=%b funct3=%b alt=%b -> ALUControl=%b (want %b)",
                         aluop_in, funct3_in, alt_in, ALUControl, expected);
            end
        end
    endtask

    task check_unknown;
        input [2:0] funct3_in;
        input       alt_in;
        input [1:0] aluop_in;
        begin
            funct3 = funct3_in; alt = alt_in; ALUop = aluop_in;
            #1;
            checks = checks + 1;
            if (ALUControl !== 3'bxxx) begin
                failures = failures + 1;
                $display("FAIL ALUop=%b funct3=%b alt=%b selects no operation: ALUControl=%b (want x)",
                         aluop_in, funct3_in, alt_in, ALUControl);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, ALUDecoder_tb);

        checks = 0;
        failures = 0;
        funct3 = 3'b000; alt = 1'b0; ALUop = 2'b00;

        // Address computation for lw/sw: add, with funct3 playing no part in it.
        check(3'b000, 1'b0, 2'b00, 3'b000);
        check(3'b111, 1'b1, 2'b00, 3'b000); // still add

        // A branch subtracts. 101 is the control value the ALU gives that, and
        // the one that makes `zero` readable as "equal".
        check(3'b000, 1'b0, 2'b01, 3'b101);
        check(3'b010, 1'b1, 2'b01, 3'b101); // funct3 is not consulted either

        // R-type and I-type ALU: funct3 picks the operation, `alt`
        // (instruction[30]) only decides sub against add.
        check(3'b000, 1'b0, 2'b10, 3'b000); // add / addi
        check(3'b000, 1'b1, 2'b10, 3'b001); // sub
        check(3'b010, 1'b0, 2'b10, 3'b100); // slt / slti - signed, the ALU's 100
        check(3'b010, 1'b1, 2'b10, 3'b100); // for slti bit 30 is part of the immediate
        check(3'b110, 1'b0, 2'b10, 3'b011); // or / ori
        check(3'b111, 1'b1, 2'b10, 3'b010); // and / andi

        // An operation the ALU has no arm for must stay unknown rather than be
        // rounded to a neighbour: a shift, an unsigned compare and xor are three
        // different instructions and the ALU implements none of them.
        check_unknown(3'b001, 1'b0, 2'b10); // slli
        check_unknown(3'b011, 1'b0, 2'b10); // sltu - not slt
        check_unknown(3'b100, 1'b0, 2'b10); // xor / xori
        check_unknown(3'b101, 1'b1, 2'b10); // srai

        // ALUop 11 has no arm in the original either, which latched the value
        // of the step before.
        check_unknown(3'b000, 1'b0, 2'b11);

        // One real step after the unknowns: a decoder that holds the last value
        // instead of decoding fails here, not only above.
        check(3'b000, 1'b1, 2'b10, 3'b001); // sub

        if (failures == 0)
            $display("ALU Decoder: %0d check(s) passed", checks);
        else begin
            $display("ALU Decoder: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d ALU Decoder check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
