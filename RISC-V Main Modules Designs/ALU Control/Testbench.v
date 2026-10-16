`timescale 1ns/1ps
// Self-checking testbench for the control unit.
//
// This is the integration of the two decoders, so it checks the one thing
// neither of them can check alone: PCSrc = branch & zero | jump, i.e. that a
// beq takes its decision from the ALU's `zero` and that a jal jumps without
// one. The bench drives `zero` itself - the ALU lives in another directory and
// the driver compiles one design directory at a time.
//
// What it replaces asserted nothing: it applied five opcodes and called
// $finish, which is why the undriven `jump` output and the decoder that never
// produced the branch control both stayed invisible.

module ALUControl_tb;
    reg  [6:0] op;
    reg  [2:0] funct3;
    reg        alt;
    reg        zero;

    wire PCSrc;
    wire jump;
    wire ALUSrc;
    wire RegWrite;
    wire MemWrite;
    wire branch;
    wire [1:0] ResultSrc;
    wire [1:0] ImmSrc;
    wire [2:0] ALUControl;

    integer checks;
    integer failures;

    ALUControl uut (
        .op(op),
        .funct3(funct3),
        .alt(alt),
        .zero(zero),
        .PCSrc(PCSrc),
        .jump(jump),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .branch(branch),
        .ResultSrc(ResultSrc),
        .ImmSrc(ImmSrc),
        .ALUControl(ALUControl)
    );

    // `br` and not `branch`: a task argument with the design's own name would
    // shadow that wire and compare the argument with itself.
    task check;
        input [6:0] op_in;
        input [2:0] funct3_in;
        input       alt_in, zero_in;
        input       pcsrc, jmp, alusrc, regwrite, memwrite, br;
        input [1:0] resultsrc, immsrc;
        input [2:0] alucontrol;
        begin
            op = op_in; funct3 = funct3_in; alt = alt_in; zero = zero_in;
            #1;
            checks = checks + 1;
            if (PCSrc !== pcsrc || jump !== jmp || ALUSrc !== alusrc ||
                RegWrite !== regwrite || MemWrite !== memwrite || branch !== br ||
                ResultSrc !== resultsrc || ImmSrc !== immsrc || ALUControl !== alucontrol) begin
                failures = failures + 1;
                $display("FAIL op=%b funct3=%b alt=%b zero=%b -> PCSrc=%b jump=%b ALUSrc=%b RgWr=%b MemWr=%b branch=%b ResultSrc=%b ImmSrc=%b ALUControl=%b",
                         op_in, funct3_in, alt_in, zero_in, PCSrc, jump, ALUSrc,
                         RegWrite, MemWrite, branch, ResultSrc, ImmSrc, ALUControl);
                $display("     want PCSrc=%b jump=%b ALUSrc=%b RgWr=%b MemWr=%b branch=%b ResultSrc=%b ImmSrc=%b ALUControl=%b",
                         pcsrc, jmp, alusrc, regwrite, memwrite, br, resultsrc, immsrc, alucontrol);
            end
        end
    endtask

    // An opcode with no arm leaves the whole bundle unknown, PCSrc included:
    // (x & 0) | x is x, so a fetched instruction that is not implemented shows
    // up here instead of resolving to "no jump".
    task check_unknown;
        input [6:0] op_in;
        begin
            op = op_in; funct3 = 3'b000; alt = 1'b0; zero = 1'b0;
            #1;
            checks = checks + 1;
            if (PCSrc !== 1'bx || jump !== 1'bx || ALUSrc !== 1'bx ||
                RegWrite !== 1'bx || MemWrite !== 1'bx || branch !== 1'bx ||
                ResultSrc !== 2'bxx || ImmSrc !== 2'bxx || ALUControl !== 3'bxxx) begin
                failures = failures + 1;
                $display("FAIL op=%b is not implemented -> PCSrc=%b jump=%b ALUSrc=%b RgWr=%b MemWr=%b branch=%b ResultSrc=%b ImmSrc=%b ALUControl=%b (want x)",
                         op_in, PCSrc, jump, ALUSrc, RegWrite, MemWrite, branch,
                         ResultSrc, ImmSrc, ALUControl);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, ALUControl_tb);

        checks = 0;
        failures = 0;
        op = 7'b0000011; funct3 = 3'b000; alt = 1'b0; zero = 1'b0;

        // lw: address in the ALU, write-back from memory.
        check(7'b0000011, 3'b000, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 2'b01, 2'b00, 3'b000);
        // sw: same address, no write-back.
        check(7'b0100011, 3'b000, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0, 2'b00, 2'b01, 3'b000);

        // beq taken: `zero` is what the ALU produced for a subtract, so it is
        // only readable as "equal" because the decoder selects 101.
        check(7'b1100011, 3'b000, 1'b0, 1'b1,
              1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 2'b10, 3'b101);
        // ... and not taken with the same instruction - the pair is the point.
        check(7'b1100011, 3'b000, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 2'b00, 2'b10, 3'b101);

        // R-type: all five operations the ALU implements.
        check(7'b0110011, 3'b000, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 3'b000); // add
        check(7'b0110011, 3'b000, 1'b1, 1'b0,
              1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 3'b001); // sub
        check(7'b0110011, 3'b111, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 3'b010); // and
        check(7'b0110011, 3'b110, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 3'b011); // or
        check(7'b0110011, 3'b010, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 3'b100); // slt

        // I-type ALU: same decode path, operand B from the immediate.
        check(7'b0010011, 3'b000, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 2'b00, 2'b00, 3'b000); // addi

        // jal: an unconditional jump, no comparison involved.
        check(7'b1101111, 3'b000, 1'b0, 1'b0,
              1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0, 2'b10, 2'b11, 3'b000);

        check_unknown(7'b0110111); // lui
        check_unknown(7'b1100111); // jalr

        // One real instruction after the unknowns: a decoder that holds on to
        // the last value fails here, not only above.
        check(7'b0000011, 3'b000, 1'b0, 1'b0,
              1'b0, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 2'b01, 2'b00, 3'b000); // lw

        if (failures == 0)
            $display("ALU Control: %0d check(s) passed", checks);
        else begin
            $display("ALU Control: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d ALU Control check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
