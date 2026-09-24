// ===============================================================================
// Ignytion IO - CRUCIBLE CORE
// Copyright (c) 2026 Ignytion IO. All rights reserved.
// Author      : IGNYTION_TECH
// File        : apb_synthesis_with_sky130pdk/01_rtl/slave1.v
// Created     : 2026-09-07
// Description : APB project source, configuration, or documentation file.
// ===============================================================================




`timescale 1ns/1ns



module slave1(
         input PCLK,PRESETn,
         input PSEL,PENABLE,PWRITE,
         input [7:0]PADDR,PWDATA,
        output [7:0]PRDATA1,
        output reg PREADY );
    
     reg [7:0] mem [0:63];

    // Combinational read mux: PADDR is already held stable by master_bridge
    // throughout SETUP+ACCESS, so no separate address register is needed on
    // the read side (a registered copy here would read back one cycle late).
    assign PRDATA1 =  mem[PADDR];

    always @(*)
       begin
         if(!PRESETn)
              PREADY = 0;
          else if(PSEL && !PENABLE && !PWRITE)
	     PREADY = 0;
	  else if(PSEL && PENABLE && !PWRITE)
	     PREADY = 1;
          else if(PSEL && !PENABLE && PWRITE)
	     PREADY = 0;
	  else if(PSEL && PENABLE && PWRITE)
	     PREADY = 1;
           else PREADY = 0;
        end

    always @(posedge PCLK)
       begin
          if(PRESETn && PSEL && PENABLE && PWRITE)
               mem[PADDR] <= PWDATA;
       end
    endmodule
