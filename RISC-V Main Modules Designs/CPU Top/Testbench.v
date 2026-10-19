`timescale 1ns / 1ps
// Self-checking testbench for the top level - the assembled single-cycle CPU.
//
// It instantiates the `CPU` module, the root the design was missing: the
// instruction memory, the control unit and the datapath, wired in the design
// rather than in the bench. The ROM's five-word program runs, every
// instruction is checked, and the branch and jump path - the one the ROM
// never reaches - is probed through the CPU's `override` inputs.
//
// The expected values are the same as the `Data Path` bench's, because this
// is the same machine: the top instantiates the datapath, the control unit
// and the instruction memory it used to wire around the datapath. A
// divergence between the two benches is a finding about the top's wiring,
// not about the arithmetic.
//
// Not every output is meaningful in every cycle, and the checks say so
// instead of inventing a value:
//
//   * the register operand is read from address instruction[24:20], which is
//     `rs2` only in R-, S- and B-type instructions. In an I- or J-type
//     instruction those five bits belong to the immediate, so the register
//     file is asked for a register the instruction never names. Those cycles
//     compare the ALU result and leave the operand alone.
//   * the memory word is only compared while the ALU result is an address
//     that has actually been written; an unwritten word is x, and "x" says
//     nothing about the design.
//
// Reset is synchronous: the PC is a register with no defined value before the
// first edge, and the first `tick` below is the one that puts it at address 0.

module CPU_Testbench;
    reg clk, reset;
    reg override;
    reg [31:0] probe;

    // What the CPU offers to look at.
    wire [31:0] instruction;
    wire        zero;
    wire [31:0] PC, WriteData, ReadData, ALUResult;

    integer checks;
    integer failures;
    integer cycle;

    CPU uut (
        .clk(clk),
        .reset(reset),
        .override(override),
        .instruction_override(probe),
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

    // The ALU's `zero` flag, where the instruction really has two operands -
    // a J-type instruction has neither. The taken and untaken pair of the
    // same branch is what makes it visible; where the PC lands is the
    // functional proof, and it is checked in the step that follows.
    task check_zero;
        input        zero_known;
        input        want_zero;
        begin
            checks = checks + 1;
            if (zero_known && zero !== want_zero) begin
                failures = failures + 1;
                $display("FAIL cycle %0d: instruction=%h zero=%b (want %b, %0s)",
                         cycle, instruction, zero, want_zero,
                         zero_known ? "checked" : "no second operand");
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, CPU_Testbench);

        checks = 0;
        failures = 0;
        cycle = 0;
        clk = 1'b0;
        reset = 1'b1;
        override = 1'b0;
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
        // From here the instruction comes through the CPU's `override` inputs
        // rather than the ROM. Every probe reads the state at the current PC,
        // which the probe instruction now defines, and then where the next
        // edge sends the PC. x1 holds 5 and x2 holds 10.

        override = 1'b1;

        // beq x1, x1, +8: the operands are equal, so `zero` is set, the branch
        // is taken, and the PC goes to 20 + 8 rather than to 20 + 4.
        probe = 32'h00108463;
        #1;
        check_step(32'h00000014, 32'h00000000, 1'b1, 32'h00000005, 1'b0, 32'h0);
        check_zero(1'b1, 1'b1);
        tick;
        check_pc(32'h0000001C);

        // beq x1, x2, +8: 5 against 10 is not equal, so the same instruction
        // falls through instead. The pair is what makes `zero` and PCSrc
        // visible at all.
        probe = 32'h00208463;
        #1;
        check_step(32'h0000001C, 32'hFFFFFFFB, 1'b1, 32'h0000000A, 1'b0, 32'h0);
        check_zero(1'b1, 1'b0);
        tick;
        check_pc(32'h00000020);

        // jal x1, +8: taken without consulting zero - it is not a branch
        // instruction. Its ALU result is not meaningful either, a J-type
        // instruction having no second register operand, so only where the PC
        // lands is checked.
        probe = 32'h008000EF;
        #1;
        check_pc(32'h00000020);
        tick;
        check_pc(32'h00000028);

        if (failures == 0)
            $display("CPU Top: %0d check(s) passed", checks);
        else begin
            $display("CPU Top: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d CPU Top check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
