// ----------------------------------------------------------------------------
// The confidential and proprietary information contained in this file may
// only be used by a person authorised under and to the extent permitted
// by a subsisting licensing agreement from ARM Limited.
//
//        (C) COPYRIGHT 2010-2013 ARM Limited.
//                ALL RIGHTS RESERVED
//
// This entire notice must be reproduced on all copies of this file
// and copies of this file may only be made by a person if such person is
// permitted to do so under the terms of a subsisting license agreement
// from ARM Limited.
//
//      SVN Information
//
//      Checked In          : $Date: 2012-09-18 17:14:17 +0100 (Tue, 18 Sep 2012) $
//
//      Revision            : $Revision: 223062 $
//
//      Release Information : Cortex-M System Design Kit-r1p0-00rel0
//
// ----------------------------------------------------------------------------
//  Purpose : AHB OnChip RAM interface. Also suitable for FPGA RAM implmentation
// ----------------------------------------------------------------------------

module exsram_model_FPGA_BRAM #(
// --------------------------------------------------------------------------
// Parameter Declarations
// --------------------------------------------------------------------------
  parameter AW       = 16) // Address width
 (
// --------------------------------------------------------------------------
// Port Definitions
// --------------------------------------------------------------------------
  input  wire          clk,      // system bus clock

  inout wire   [31:0]   sram_data_io,    //32bit  
  input wire  [AW-1:0] sram_Address_io,  //16bit
  input wire         sram_OEn_io             ,
  input wire         sram_WEn_io
  
  );   // SRAM Chip Select  (active high)

wire [31:0] I,O;
reg sram_OEn_io_d,sram_WEn_io_d;
always(@posedge clk)sram_OEn_io_d <= sram_OEn_io;
always(@posedge clk)sram_WEn_io_d <= sram_WEn_io;
assign I = (~sram_OEn_io && ~sram_WEn_io)? sram_data_io : 0;
assign sram_data_io = (~sram_OEn_io_d && sram_WEn_io_d)? O : 0;

/*
IP_sram sram_name(
.DO(O),
.DI(I),
.A(sram_Address_io),
.WEB({~sram_WEn_io,~sram_WEn_io,~sram_WEn_io,~sram_WEn_io}),
.WEB({~sram_WEn_io,~sram_WEn_io,~sram_WEn_io,~sram_WEn_io}),
.CK(clk),
.CS(~sram_OEn_io),
.OE(1'b1)
)
*/

blk_mem_gen_3 SRAM (
.clka(clk),  // input wire clka
.ena(~sram_OEn_io),   // input wire ena
.wea(~sram_WEn_io),   // input wire [3 : 0] wea
 .addra(sram_Address_io), // input wire [14 : 0] addra
 .dina(I),  // input wire [31 : 0] dina
 .douta(O) // output wire [31 : 0] douta
);

endmodule
