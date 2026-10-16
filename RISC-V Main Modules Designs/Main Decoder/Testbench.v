`timescale 1ns / 1ps
// Self-checking testbench for the main control decoder.
//
// One step per instruction form, and *every* output is compared on every step.
// A decoder is a wide combinational table: the failure that hurts is the one
// in the output the author of the bench was not looking at while writing the
// row. An opcode this design does not implement must produce unknown control,
// not a plausible-looking default.
//
// What it replaces asserted nothing: it drove a 1-bit `op` into a 7-bit port,
// hence a compile error, and called $finish after 10 ns without an expected
// value anywhere in the file.

module MainDecoder_tb;
    reg  [6:0] op;
    wire RegWrite, MemWrite, Branch, ALUSrc, jump;
    wire [1:0] ALUop, ImmSrc, ResultSrc;

    integer checks;
    integer failures;

    MainDecoder uut (
        .op(op),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .Branch(Branch),
        .ALUSrc(ALUSrc),
        .ALUop(ALUop),
        .ImmSrc(ImmSrc),
        .ResultSrc(ResultSrc),
        .jump(jump)
    );

    // The opcode, then the outputs in the order the design declares them.
    task check;
        input [6:0] opcode;
        input       regwrite, memwrite, branch, alusrc;
        input [1:0] aluop, immsrc, resultsrc;
        input       jmp;
        begin
            op = opcode;
            #1;
            checks = checks + 1;
            if (RegWrite !== regwrite || MemWrite !== memwrite ||
                Branch !== branch || ALUSrc !== alusrc ||
                ALUop !== aluop || ImmSrc !== immsrc ||
                ResultSrc !== resultsrc || jump !== jmp) begin
                failures = failures + 1;
                $display("FAIL op=%b -> RgWr=%b MemWr=%b Branch=%b ALUSrc=%b ALUop=%b ImmSrc=%b ResultSrc=%b jump=%b",
                         opcode, RegWrite, MemWrite, Branch, ALUSrc, ALUop, ImmSrc, ResultSrc, jump);
                $display("     want    RgWr=%b MemWr=%b Branch=%b ALUSrc=%b ALUop=%b ImmSrc=%b ResultSrc=%b jump=%b",
                         regwrite, memwrite, branch, alusrc, aluop, immsrc, resultsrc, jmp);
            end
        end
    endtask

    // An opcode this design does not implement has to leave the whole control
    // bundle unknown: that is what makes a mis-decoded instruction show up,
    // instead of turning it into a no-op that looks like it worked.
    task check_unknown;
        input [6:0] opcode;
        begin
            op = opcode;
            #1;
            checks = checks + 1;
            if (RegWrite !== 1'bx || MemWrite !== 1'bx || Branch !== 1'bx ||
                ALUSrc !== 1'bx || ALUop !== 2'bxx || ImmSrc !== 2'bxx ||
                ResultSrc !== 2'bxx || jump !== 1'bx) begin
                failures = failures + 1;
                $display("FAIL op=%b is not implemented: RgWr=%b MemWr=%b Branch=%b ALUSrc=%b ALUop=%b ImmSrc=%b ResultSrc=%b jump=%b (want x)",
                         opcode, RegWrite, MemWrite, Branch, ALUSrc, ALUop, ImmSrc, ResultSrc, jump);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, MainDecoder_tb);

        checks = 0;
        failures = 0;
        op = 7'b0000011;

        //      op        RgWr MemWr Branch ALUSrc ALUop  ImmSrc ResultSrc jump
        check(7'b0000011, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 2'b00, 2'b01, 1'b0); // lw
        check(7'b0100011, 1'b0, 1'b1, 1'b0, 1'b1, 2'b00, 2'b01, 2'b00, 1'b0); // sw
        check(7'b1100011, 1'b0, 1'b0, 1'b1, 1'b0, 2'b01, 2'b10, 2'b00, 1'b0); // beq
        check(7'b0010011, 1'b1, 1'b0, 1'b0, 1'b1, 2'b10, 2'b00, 2'b00, 1'b0); // addi
        check(7'b0110011, 1'b1, 1'b0, 1'b0, 1'b0, 2'b10, 2'b00, 2'b00, 1'b0); // R-type
        check(7'b1101111, 1'b1, 1'b0, 1'b0, 1'b0, 2'b00, 2'b11, 2'b10, 1'b1); // jal

        // The R-type arm above did not exist: add/sub/and/or/slt fell into
        // `default` and wrote nothing at all.
        check_unknown(7'b1100111); // jalr: its PC comes from the ALU result
        check_unknown(7'b0110111); // lui
        check_unknown(7'b0010111); // auipc
        check_unknown(7'b1111111); // not an opcode

        // A real instruction after the unknowns: a decoder that holds the last
        // value instead of decoding fails here, not only above.
        check(7'b0000011, 1'b1, 1'b0, 1'b0, 1'b1, 2'b00, 2'b00, 2'b01, 1'b0); // lw

        if (failures == 0)
            $display("Main Decoder: %0d check(s) passed", checks);
        else begin
            $display("Main Decoder: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Main Decoder check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
