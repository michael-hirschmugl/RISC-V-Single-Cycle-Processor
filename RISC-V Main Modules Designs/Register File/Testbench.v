`timescale 1ns / 1ps
// Self-checking testbench for the register file.
//
// What it replaces asserted nothing: six 1-bit toggle trains driven into
// inputs up to 32 bits wide, and $finish after 10 ns.
//
// The defect this pins is in the read path: it tested `A1 == 1`, so x1 was the
// only readable register and every other read answered 0. The other RISC-V
// rule is the one about x0 - it reads as zero and a write to it is dropped -
// and the design stored a write to x0 like an ordinary register.
//
// Both ports are read at once on every step: a file whose second port ignored
// A2 would pass a test that only ever looked at RD1.

module RegFile_tb;
    reg  WE3, clk;
    reg  [4:0]  A1, A2, A3;
    reg  [31:0] WD3;
    wire [31:0] RD1, RD2;

    integer checks;
    integer failures;

    RegFile uut (
        .WE3(WE3),
        .clk(clk),
        .A1(A1),
        .A2(A2),
        .A3(A3),
        .WD3(WD3),
        .RD1(RD1),
        .RD2(RD2)
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
        end
    endtask

    // The write port, under the control of WE3.
    task write_reg;
        input [4:0]  address;
        input [31:0] value;
        input        enable;
        begin
            A3 = address; WD3 = value; WE3 = enable;
            tick;
            WE3 = 1'b0;
        end
    endtask

    task check_reads;
        input [4:0]  a1, a2;
        input [31:0] want1, want2;
        begin
            A1 = a1; A2 = a2;
            #1;
            checks = checks + 1;
            if (RD1 !== want1 || RD2 !== want2) begin
                failures = failures + 1;
                $display("FAIL A1=%0d A2=%0d -> RD1=%h (want %h), RD2=%h (want %h)",
                         a1, a2, RD1, want1, RD2, want2);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, RegFile_tb);

        checks = 0;
        failures = 0;
        clk = 1'b0;
        WE3 = 1'b0;
        A1 = 5'd0; A2 = 5'd0; A3 = 5'd0; WD3 = 32'd0;

        write_reg(5'd1,  32'h11111111, 1'b1);
        write_reg(5'd2,  32'h22222222, 1'b1);
        write_reg(5'd3,  32'h33333333, 1'b1);
        write_reg(5'd5,  32'h55555555, 1'b1);
        write_reg(5'd31, 32'hFFFFFFFF, 1'b1);

        // x1 was the only address the original could read; x3, x5 and x31 are
        // the ones it answered 0 for.
        check_reads(5'd1,  5'd2,  32'h11111111, 32'h22222222);
        check_reads(5'd3,  5'd1,  32'h33333333, 32'h11111111);
        check_reads(5'd5,  5'd31, 32'h55555555, 32'hFFFFFFFF);
        check_reads(5'd31, 5'd2,  32'hFFFFFFFF, 32'h22222222);

        // x0 reads as zero ...
        check_reads(5'd0, 5'd3, 32'h00000000, 32'h33333333);
        check_reads(5'd1, 5'd0, 32'h11111111, 32'h00000000);

        // ... and a write to it is dropped.
        write_reg(5'd0, 32'hDEADBEEF, 1'b1);
        check_reads(5'd0, 5'd0, 32'h00000000, 32'h00000000);

        // A write with WE3 low does not happen ...
        write_reg(5'd5, 32'hAAAAAAAA, 1'b0);
        check_reads(5'd5, 5'd5, 32'h55555555, 32'h55555555);

        // ... and one with it high does.
        write_reg(5'd5, 32'hAAAAAAAA, 1'b1);
        check_reads(5'd5, 5'd2, 32'hAAAAAAAA, 32'h22222222);

        if (failures == 0)
            $display("Register File: %0d check(s) passed", checks);
        else begin
            $display("Register File: %0d of %0d check(s) failed", failures, checks);
            $fatal(1, "%0d of %0d Register File check(s) failed", failures, checks);
        end

        $finish;
    end
endmodule
