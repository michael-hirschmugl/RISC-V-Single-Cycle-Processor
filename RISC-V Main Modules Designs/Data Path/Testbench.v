`timescale 1ns / 1ps
// Self-checking testbench for the datapath - the integration check.
//
// What it replaces drove nothing: `Data_Path` was instantiated with every
// control signal left as an undriven `wire`, no instruction, and `$finish`
// ten nanoseconds later. It could not check anything, because nothing drove
// it - and those undriven controls were most of the warnings the file had.
//
// This bench completes the datapath into a single-cycle CPU: the instruction
// memory and the control unit are put around it. Both are declared in this
// directory's own `Design.v` - the datapath carries a copy of every module it
// needs, which is also why one directory is one compilation - so nothing has
// to be pulled in from a sibling directory.
//
// The program is the one the instruction memory ships:
//
//     li   x1, 5        addi x1, x0, 5
//     li   x2, 10       addi x2, x0, 10
//     add  x3, x1, x2
//     sw   x3, 0(x0)
//     lw   x4, 0(x0)
//
// and every instruction is checked, not just the end: the PC, the value the
// ALU produces, the register operand the instruction names, and the memory
// word. The store/load pair is what makes the register file observable at all
// - the datapath has no port for a register value, so "x3 holds 15" is checked
// by storing it and reading it back.
//
// Not every output is meaningful in every cycle, and the checks say so instead
// of inventing a value:
//
//   * the second register operand is read from address instruction[24:20],
//     which is `rs2` only in R-, S- and B-type instructions. In an I- or
//     J-type instruction those five bits belong to the immediate, so the
//     register file is asked for a register the instruction never names. It
//     costs nothing - `ALUSrc` picks the immediate for the ALU - but the
//     value is whatever that register happens to hold, and mostly that is x,
//     because nothing has written it. Those cycles compare the ALU result and
//     leave the operand alone.
//   * the memory word is only compared while the ALU result is an address that
//     has actually been written; an unwritten word is x, and "x" says nothing
//     about the design.
//
// The ROM holds no branch, so the branch and jump path - PCSrc through the mux
// into the PC - is probed at the end by driving the instruction from the bench
// instead. That is the path the ALU and the control unit were repaired for,
// and the one part of it a straight-line program never reaches.
//
// Reset is synchronous: the PC is a register with no defined value before the
// first edge, and the first `tick` below is the one that puts it at address 0.

module RISC_V_Testbench;
    reg clk, reset;

    // Instruction fetch, control and datapath: a single-cycle CPU in three
    // instantiations.
    wire [31:0] fetched;
    reg  [31:0] probe;
    reg         probing;
    wire [31:0] instruction;

    assign instruction = probing ? probe : fetched;

    wire        zero, branch, jump, PCSrc, ALUSrc, RegWrite, MemWrite;
    wire [1:0]  ResultSrc, ImmSrc;
    wire [2:0]  alu_control;

    // What the datapath offers to look at.
    wire [31:0] PC, WriteData, ReadData, ALUResult;

    integer checks;
    integer failures;
    integer cycle;

    Instruction_Memory im (
        .A(PC),
        .RD(fetched)
    );

    ALUControl ctrl (
        .op(instruction[6:0]),
        .funct3(instruction[14:12]),
        .alt(instruction[30]),
        .zero(zero),
        .PCSrc(PCSrc),
        .jump(jump),
        .branch(branch),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .ImmSrc(ImmSrc),
        .ALUControl(alu_control)
    );

    Data_Path dp (
        .clk(clk),
        .reset(reset),
        .PCSrc(PCSrc),
        .jump(jump),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .ALUControl(alu_control),
        .ImmSrc(ImmSrc),
        .instruction(instruction),
        .zero(zero),
        .PC(PC),
        .WriteData(WriteData),
        .ReadData(ReadData),
        .ALUResult(ALUResult)
    );

    // One clock cycle, driven from the bench rather than by an `always` block.
    // The rising edge comes first, the state is read one time unit later, and
    // the rest of the cycle follows with the clock low - so a check always sees
    // what the edge it follows produced. Driving it here also keeps every
    // `@(...)` out of the procedures: the lint pass runs Verilator with
    // --no-timing, which allows an event control only at the very top of a
    // procedure, and a task called several times inlines to more than one.
    task tick;
        begin
            clk = 1'b1;
            #1;
            clk = 1'b0;
            #9;
            cycle = cycle + 1;
        end
    endtask

    // The PC and the ALU result are always meaningful. The register operand
    // and the memory word are compared only where the instruction they belong
    // to actually defines them - see the header.
    task check_step;
        input [31:0] want_pc, want_alu;
        input        write_known;
        input [31:0] want_write;
        input        read_known;
        input [31:0] want_read;
        begin
            checks = checks + 1;
            if (PC !== want_pc || ALUResult !== want_alu ||
                (write_known && WriteData !== want_write) ||
                (read_known && ReadData !== want_read)) begin
                failures = failures + 1;
                $display("FAIL cycle %0d: instruction=%h PC=%h ALUResult=%h WriteData=%h ReadData=%h",
                         cycle, instruction, PC, ALUResult, WriteData, ReadData);
                $display("               want PC=%h ALUResult=%h WriteData=%h (%0s) ReadData=%h (%0s)",
                         want_pc, want_alu, want_write,
                         write_known ? "checked" : "not a register operand",
                         want_read, read_known ? "checked" : "not written yet");
            end
        end
    endtask

    task check_pc;
        input [31:0] want_pc;
        begin
            checks = checks + 1;
            if (PC !== want_pc) begin
                failures = failures + 1;
                $display("FAIL cycle %0d: instruction=%h PC=%h (want %h)",
                         cycle, instruction, PC, want_pc);
            end
        end
    endtask

    // The two flags the control unit derives from the instruction: `zero` from
    // the ALU and `branch` from the main decoder. Only their product decides
    // whether a branch moves the PC, so a taken and an untaken branch of the
    // same kind are what makes them visible. `zero` is a comparison of the two
    // ALU operands, so it is compared only where the instruction really has
    // two - a J-type instruction has neither.
    task check_flags;
        input        zero_known;
        input        want_zero, want_branch;
        begin
            checks = checks + 1;
            if ((zero_known && zero !== want_zero) || branch !== want_branch) begin
                failures = failures + 1;
                $display("FAIL cycle %0d: instruction=%h zero=%b (want %b, %0s) branch=%b (want %b)",
                         cycle, instruction, zero, want_zero,
                         zero_known ? "checked" : "no second operand",
                         branch, want_branch);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, RISC_V_Testbench);

        checks = 0;
        failures = 0;
        cycle = 0;
        clk = 1'b0;
        reset = 1'b1;
        probing = 1'b0;
        probe = 32'd0;

        // Reset: the PC starts at 0, the first word of the program. The first
        // instruction is already in flight - an immediate add into x1 - so the
        // ALU is adding x0 and 5.
        tick;
        check_step(32'h00000000, 32'h00000005, 1'b0, 32'h0, 1'b0, 32'h0);

        reset = 1'b0;

        // The second instruction: the PC has moved on by four and the ALU is
        // computing the second immediate the same way.
        tick;
        check_step(32'h00000004, 32'h0000000A, 1'b0, 32'h0, 1'b0, 32'h0);

        // The add: x1 and x2 hold 5 and 10 now, so the operand the register
        // file offers as the ALU's second source is 10.
        tick;
        check_step(32'h00000008, 32'h0000000F, 1'b1, 32'h0000000A, 1'b0, 32'h0);

        // The store: its address is x0 + 0, its data is x3 = 15, and the word
        // at address 0 is still unknown - nothing has written it yet.
        tick;
        check_step(32'h0000000C, 32'h00000000, 1'b1, 32'h0000000F, 1'b0, 32'h0);

        // The load: the store landed on the edge above, so address 0 reads
        // back as 15. That is the register file's contents, observed through
        // the memory.
        tick;
        check_step(32'h00000010, 32'h00000000, 1'b1, 32'h00000000, 1'b1, 32'h0000000F);

        // Five instructions, one word each: the PC has walked 0, 4, 8, 12, 16
        // and is at 20, where the ROM has no word left.
        tick;
        check_pc(32'h00000014);

        // -- the branch and jump path ---------------------------------------
        //
        // From here the instruction comes from the bench rather than the ROM.
        // Every probe reads the state at the current PC, which the probe
        // instruction now defines, and then where the next edge sends the PC.
        // x1 holds 5 and x2 holds 10.

        probing = 1'b1;

        // beq x1, x1, +8: the operands are equal, so `zero` is set, the branch
        // is taken, and the PC goes to 20 + 8 rather than to 20 + 4.
        probe = 32'h00108463;
        #1;
        check_step(32'h00000014, 32'h00000000, 1'b1, 32'h00000005, 1'b0, 32'h0);
        check_flags(1'b1, 1'b1, 1'b1);
        tick;
        check_pc(32'h0000001C);

        // beq x1, x2, +8: 5 against 10 is not equal, so the same instruction
        // falls through instead. It is still a branch - only the ALU flag
        // differs - and the pair is what makes `zero` and PCSrc visible at all.
        probe = 32'h00208463;
        #1;
        check_step(32'h0000001C, 32'hFFFFFFFB, 1'b1, 32'h0000000A, 1'b0, 32'h0);
        check_flags(1'b1, 1'b0, 1'b1);
        tick;
        check_pc(32'h00000020);

        // jal x1, +8: taken without consulting zero or the branch flag - it is
        // not a branch instruction, so `branch` is low. Its ALU result is not
        // meaningful either, a J-type instruction having no second register
        // operand, so only where the PC lands is checked.
        probe = 32'h008000EF;
        #1;
        check_pc(32'h00000020);
        check_flags(1'b0, 1'b0, 1'b0);
        tick;
        check_pc(32'h00000028);

        if (failures == 0)
            $display("Data Path: %0d check(s) passed", checks);
        else begin
            $display("Data Path: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Data Path check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
