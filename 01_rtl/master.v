// ===============================================================================
// Ignytion IO - CRUCIBLE CORE
// Copyright (c) 2026 Ignytion IO. All rights reserved.
// Author      : IGNYTION_TECH
// File        : apb_synthesis_with_sky130pdk/01_rtl/master.v
// Created     : 2026-09-07
// Description : APB project source, configuration, or documentation file.
// ===============================================================================




`timescale 1ns/1ns

  module master_bridge(
	input [8:0]apb_write_paddr,apb_read_paddr,
	input [7:0] apb_write_data,PRDATA,         
	input PRESETn,PCLK,READ_WRITE,transfer,PREADY,
	output PSEL1,PSEL2,
	output reg PENABLE,
	output reg [8:0]PADDR,
	output reg PWRITE,
	output reg [7:0]PWDATA,apb_read_data_out,
	output PSLVERR ); 
       // integer i,count;
   
  reg [2:0] state, next_state;

  reg invalid_setup_error,
      setup_error,
      invalid_read_paddr,
      invalid_write_paddr,
      invalid_write_data ;
  
  localparam IDLE = 3'b001, SETUP = 3'b010, ENABLE = 3'b100 ;


  // State register.
  always @(posedge PCLK)
  begin
	if(!PRESETn)
		state <= IDLE;
	else
		state <= next_state;
  end

  // Next-state logic: pure combinational, single writer of next_state.
  // Mirrors the APB operating-state diagram exactly (spec Chapter 4):
  //   SETUP always moves to ACCESS on the next clock edge (unconditional);
  //   ACCESS is only exited when PREADY is HIGH, regardless of `transfer`.
  always @(*)
  begin
	if(!PRESETn)
	     next_state = IDLE;
	else
	  case(state)
	     IDLE:    next_state = transfer ? SETUP : IDLE;
	     SETUP:   next_state = ENABLE;
	     ENABLE:  next_state = PREADY ? (transfer ? SETUP : IDLE) : ENABLE;
	     default: next_state = IDLE;
	  endcase
  end

  // Registered Moore outputs. PADDR/PWDATA/PWRITE are captured once during
  // SETUP and held through ACCESS via normal register retention (spec 4.1:
  // these must not change between SETUP and ACCESS or across ACCESS cycles).
  always @(posedge PCLK)
  begin
	if(!PRESETn)
	  begin
	     PENABLE <= 0;
	     PWRITE  <= 0;
	  end
	else
	  case(state)
	     IDLE: begin
		PENABLE <= 0;
	     end

	     SETUP: begin
		PENABLE <= 0;
		PWRITE  <= ~READ_WRITE;
		if(READ_WRITE)
		  PADDR <= apb_read_paddr;
		else begin
		  PADDR  <= apb_write_paddr;
		  PWDATA <= apb_write_data;
		end
	     end

	     ENABLE: begin
		if(PSEL1 || PSEL2)
		  PENABLE <= 1;
		if(PREADY && READ_WRITE)
		  apb_read_data_out <= PRDATA;
	     end

	     default: PENABLE <= 0;
	  endcase
  end

     assign {PSEL1,PSEL2} = ((state != IDLE) ? (PADDR[8] ? {1'b0,1'b1} : {1'b1,1'b0}) : 2'd0);

  // PSLVERR LOGIC
  
  always @(*)
       begin
        if(!PRESETn)
	    begin
	     setup_error =0;
	     invalid_read_paddr = 0;
	     invalid_write_paddr = 0;
	     invalid_write_data = 0;
	    end
        else
	 begin	
          begin
	  if(state == IDLE && next_state == ENABLE)
   		  setup_error = 1;
	  else setup_error = 0;
          end
          begin
          if((apb_write_data===8'dx) && (!READ_WRITE) && (state==SETUP || state==ENABLE))
		  invalid_write_data =1;
	  else invalid_write_data = 0;
          end
          begin
	  if((apb_read_paddr===9'dx) && READ_WRITE && (state==SETUP || state==ENABLE))
		  invalid_read_paddr = 1;
	  else  invalid_read_paddr = 0;
          end
          begin
          if((apb_write_paddr===9'dx) && (!READ_WRITE) && (state==SETUP || state==ENABLE))
		  invalid_write_paddr =1;
          else invalid_write_paddr =0;
          end
          begin
	  if(state == SETUP)
            begin
                 if(PWRITE)
                      begin
                         if(PADDR==apb_write_paddr && PWDATA==apb_write_data)
                              setup_error=1'b0;
                         else
                               setup_error=1'b1;
                       end
                 else 
                       begin
                          if (PADDR==apb_read_paddr)
                                 setup_error=1'b0;
                          else
                                 setup_error=1'b1;
                       end    
              end 
          
         else setup_error=1'b0;
         end 
       end
       invalid_setup_error = setup_error ||  invalid_read_paddr || invalid_write_data || invalid_write_paddr  ;
     end 

   assign PSLVERR =  invalid_setup_error ;

	 

 endmodule
