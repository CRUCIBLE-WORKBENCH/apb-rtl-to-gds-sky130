// ===============================================================================
// Ignytion IO - CRUCIBLE CORE
// Copyright (c) 2026 Ignytion IO. All rights reserved.
// Author      : IGNYTION_TECH
// File        : apb_synthesis_with_sky130pdk/02_sim/test.v
// Created     : 2026-09-07
// Description : APB project source, configuration, or documentation file.
// ===============================================================================

////////////////////////////////////////////////
//
// Design: APB2 Protocol self-checking testbench
//
// Drives writes and reads through the real APB_Protocol top-level ports,
// mirrors expected values in a local shadow memory, and asserts read-back
// data matches what was written. Also exercises a back-to-back transfer
// (SETUP->ACCESS->SETUP without returning to IDLE) since that path only
// works correctly with the operating-state fix applied to master.v.
//
///////////////////////////////////////////////

`timescale 1ns/1ns

module test;

  reg PCLK, PRESETn, transfer, READ_WRITE;
  reg  [8:0] apb_write_paddr;
  reg  [7:0] apb_write_data;
  reg  [8:0] apb_read_paddr;
  wire [7:0] apb_read_data_out;
  wire       PSLVERR;

  localparam ACCESS = 3'b100;
  localparam NUM_REGS = 16;

  reg [7:0] shadow1 [0:63];
  reg [7:0] shadow2 [0:63];

  integer errors;
  integer i;
  reg [7:0] rdata;

  APB_Protocol dut (
      PCLK,
      PRESETn,
      transfer,
      READ_WRITE,
      apb_write_paddr,
      apb_write_data,
      apb_read_paddr,
      PSLVERR,
      apb_read_data_out
  );

  initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
  end

  // Single write transaction: drives inputs, waits for the transfer's
  // PREADY pulse, then drops `transfer` one negedge BEFORE the completing
  // posedge so the FSM's ACCESS-exit decision (transfer?SETUP:IDLE) sees it
  // low and returns to IDLE, instead of looping back into SETUP.
  task automatic apb_write(input [8:0] addr, input [7:0] data);
    begin
      @(negedge PCLK);
      READ_WRITE      = 1'b0;
      apb_write_paddr = addr;
      apb_write_data  = data;
      transfer        = 1'b1;
      wait (dut.PREADY == 1'b1);
      @(negedge PCLK);
      transfer = 1'b0;
      @(posedge PCLK); // completing edge: write lands, FSM returns to IDLE
      if (addr[8]) shadow2[addr[5:0]] = data;
      else         shadow1[addr[5:0]] = data;
      $display("[%0t] WRITE addr=%0d data=%0d", $time, addr, data);
    end
  endtask

  // Single read transaction: same shape as apb_write. Samples
  // apb_read_data_out one time unit after the completing edge, so it reads
  // the value the RTL just captured via nonblocking assignment on that same
  // edge rather than racing it in the same simulation delta.
  task automatic apb_read(input [8:0] addr, output [7:0] rdata_out);
    begin
      @(negedge PCLK);
      READ_WRITE     = 1'b1;
      apb_read_paddr = addr;
      transfer       = 1'b1;
      wait (dut.PREADY == 1'b1);
      @(negedge PCLK);
      transfer = 1'b0;
      @(posedge PCLK); // completing edge: apb_read_data_out captured here
      #1;
      rdata_out = apb_read_data_out;
      $display("[%0t] READ  addr=%0d data=%0d", $time, addr, rdata_out);
    end
  endtask

  task automatic check(input [8:0] addr, input [7:0] actual, input [7:0] expected);
    begin
      if (actual !== expected) begin
        $display("[%0t] MISMATCH addr=%0d expected=%0d actual=%0d",
                  $time, addr, expected, actual);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    $dumpfile("apbWaveform.vcd");
    $dumpvars(0, test);
  end

  initial begin
      errors          = 0;
      PRESETn         = 0;
      transfer        = 0;
      READ_WRITE      = 0;
      apb_write_paddr = 0;
      apb_write_data  = 0;
      apb_read_paddr  = 0;
      repeat (2) @(posedge PCLK);
      PRESETn = 1;
      @(posedge PCLK);

      // --- Phase 1: write a pattern to both slaves, single-shot transfers.
      for (i = 0; i < NUM_REGS; i = i + 1)
        apb_write({1'b0, i[7:0]}, 8'hA0 + i);
      for (i = 0; i < NUM_REGS; i = i + 1)
        apb_write({1'b1, i[7:0]}, 8'h50 + i);

      // --- Phase 2: read everything back, self-check against shadow mem.
      for (i = 0; i < NUM_REGS; i = i + 1) begin
        apb_read({1'b0, i[7:0]}, rdata);
        check({1'b0, i[7:0]}, rdata, shadow1[i]);
      end
      for (i = 0; i < NUM_REGS; i = i + 1) begin
        apb_read({1'b1, i[7:0]}, rdata);
        check({1'b1, i[7:0]}, rdata, shadow2[i]);
      end

      // --- Phase 3: back-to-back writes, transfer held high across the
      // SETUP->ACCESS->SETUP boundary (no return to IDLE in between). Only
      // behaves correctly with the spec-aligned FSM fix in master.v.
      @(negedge PCLK);
      READ_WRITE      = 1'b0;
      apb_write_paddr = {1'b0, 8'd20};
      apb_write_data  = 8'hCC;
      transfer        = 1'b1;
      wait (dut.PREADY == 1'b1);
      @(posedge PCLK); // write#1's completing edge; transfer still high -> loops to SETUP
      // do not drop transfer: immediately issue the next write
      apb_write_paddr = {1'b0, 8'd21};
      apb_write_data  = 8'hDD;
      wait (dut.PREADY == 1'b0); // let write#1's trailing PREADY pulse actually drop
      wait (dut.PREADY == 1'b1); // now wait for write#2's own, new PREADY pulse
      @(negedge PCLK);
      transfer = 1'b0;
      @(posedge PCLK); // write#2's completing edge
      shadow1[20] = 8'hCC;
      shadow1[21] = 8'hDD;
      $display("[%0t] BACK-TO-BACK WRITE addr=20 data=CC, addr=21 data=DD", $time);

      apb_read({1'b0, 8'd20}, rdata);
      check({1'b0, 8'd20}, rdata, shadow1[20]);
      apb_read({1'b0, 8'd21}, rdata);
      check({1'b0, 8'd21}, rdata, shadow1[21]);

      repeat (4) @(posedge PCLK);

      if (errors == 0)
        $display("\n==== PASS: all checks matched ====\n");
      else
        $display("\n==== FAIL: %0d mismatch(es) ====\n", errors);

      $finish;
  end

endmodule
