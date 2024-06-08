module U_wr_SRAM(

input wire [19:0]sram_Address                ,        //20bit
input wire [15:0]sram_Input                  ,        //16bit
output wire [15:0]  sram_Output              ,       //16bit

input wire          sram_write               ,
input wire          sram_read                ,

inout wire   [15:0]   sram_data_io          ,     
output wire  [19:0] sram_Address_io         ,  
output wire         sram_OEn_io             ,
output wire         sram_WEn_io
);
    
assign sram_Address_io =   sram_Address                     ;
assign sram_data_io =  sram_write  ? sram_Input  : 16'bz    ;
assign sram_Output =   sram_read   ?sram_data_io :   16'b0  ;
assign sram_OEn_io    =  (sram_read||sram_write )  ? 0 : 1   ;
//assign sram_OEn_io    =  0                              ;
assign sram_WEn_io    =  sram_write  ? 0 : 1            ;
     
endmodule