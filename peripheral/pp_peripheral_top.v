`include "pvt_int_defs.vh"
module pp_peripheral_top(
       clk,
       rst,
       addr,
       wr,
       rd,
       data_in,
       data_out,
       //---------- uart ----------
       uart0_tx,
       uart0_rx,
       //-------- gpio -------------
       gpio_in,
       gpio_out, 
       //-------- timer ------------
       timer,
      //-------- DMA control ------------
       SDAddr,
       SDCounts,
       DestAddr,
       DMAEN
);
input  clk;
input  rst;
input  [7:0]addr;
input  wr;
input  rd;
input  [31:0]data_in;
output [31:0]data_out;

output uart0_tx;
input  uart0_rx;
input  [31:0]gpio_in; 
output [31:0]gpio_out;  

output timer;

output [31:0] SDAddr;
output [31:0] SDCounts;
output [31:0] DestAddr;
output [31:0] DMAEN;

wire uart0_tx;


//-----------------------------------------------------------------
// clock & reset bypass for test mode
//-----------------------------------------------------------------
//-----------------------------------------------------------------


//------------------ GPIO -------------------------------------------
reg [31:0]gpio_ctrl; 
reg [31:0]gpio_rctrl;
reg [31:0]gpio_wdata;
reg [31:0]gpio_rdata;

always @(posedge clk or negedge rst)
begin
  if(!rst) begin
    gpio_ctrl <= 32'h0; 
    gpio_wdata <= 32'h0;
    gpio_rdata <= 32'h0;
    gpio_rctrl <= 32'h0;
  end
  else begin
    if((addr == `GPIO_CTRL) && wr) gpio_ctrl <= data_in[31:0];
    if((addr == `GPIO_RCTRL) && wr) gpio_rctrl <= data_in[31:0];
    if((addr == `GPIO_OUT) && wr) gpio_wdata <= data_in[31:0];
    gpio_rdata <= gpio_in[31:0];
  end
end

genvar k;
generate
  for(k=0; k < 32; k=k+1) begin:GPIO_OUTDATA
    assign gpio_out[k] = (gpio_ctrl[k] == 1'b1)? gpio_wdata[k]: 1'bz; 
  end
endgenerate

//------------------------- output -----------------------------
reg [7:0]addr_reg;
reg rd_reg;

always @(posedge clk or negedge rst)
begin
  if(!rst) begin
     addr_reg <= 8'h0; 
     rd_reg   <= 1'b0;
  end
  else begin 
     addr_reg <= addr;
     rd_reg   <= rd;
  end
end

genvar j;
generate
  for(j=0; j < 32; j=j+1) begin:GPIO_INDATA
    assign data_out[j] = (addr_reg == `GPIO_OUT) & rd_reg & (gpio_rctrl[j]) ? gpio_rdata[j] :  1'b0;
                         //((addr_reg == `GPIO_CTRL) & rd_reg) ? gpio_ctrl[j] : 1'b0;
  end
endgenerate

//------------------ UART0 ------------------------------------------
wire tx_fifo0_wrreq;
wire [7:0]tx_fifo0_data;
wire rx_fifo0_rdreq;
wire [7:0]rx_fifo0_q;
wire [8:0]tx_fifo0_wrusedw;
wire [8:0]rx_fifo0_rdusedw;
wire tx_fifo0_overflow;
wire rx_fifo0_overflow;
wire tx_fifo0_wrfull;
wire tx_fifo0_rdempty;
wire rx_fifo0_wrfull;
wire rx_fifo0_rdempty;

reg [1:0]uart0_check_flag;
reg uart0_stop_flag;
reg [1:0]uart0_data_flag;
reg [13:0]uart0_baud_rate;
reg fifo0_rst;

always @(posedge clk or negedge rst)
begin
  if(!rst)
    begin
      uart0_check_flag <= 2'b0;
      uart0_stop_flag  <= 1'b0;
      uart0_data_flag  <= 2'b0;
      uart0_baud_rate  <= 14'd0;
      fifo0_rst        <= 1'b1;
    end 
  else 
    begin
      if(wr && (addr == `UART0_CTRL))  uart0_check_flag <= data_in[4:3];  
      if(wr && (addr == `UART0_CTRL))  uart0_stop_flag  <= data_in[2];  
      if(wr && (addr == `UART0_CTRL))  uart0_data_flag  <= data_in[1:0];
      if(wr && (addr == `UART0_BAUD))  uart0_baud_rate  <= data_in[13:0];
      if(wr && (addr == `RST_FIFO0))         fifo0_rst  <= data_in[0];
    end
end

assign tx_fifo0_wrreq = (wr && (addr == `TX_FIFO0))?1'b1:1'b0;
assign tx_fifo0_data  = data_in[7:0];
assign rx_fifo0_rdreq = (rd && (addr == `RX_FIFO0))?1'b1:1'b0;

pp_uart0 pp_uart0(
        .clk            (clk),
        .rst            (rst),
        .soft_rst       (fifo0_rst),

        //-------------tx fifo --------------
        .tx_fifo_wrreq  (tx_fifo0_wrreq),
        .tx_fifo_data   (tx_fifo0_data),
        .tx_fifo_wrfull (tx_fifo0_wrfull),
        .tx_fifo_rdempty(tx_fifo0_rdempty),
        .tx_fifo_wrusedw(tx_fifo0_wrusedw),
        .tx_error       (tx_fifo0_overflow),
        //-------------rx fifo --------------
        .rx_fifo_rdreq  (rx_fifo0_rdreq),
        .rx_fifo_q      (rx_fifo0_q),
        .rx_fifo_wrfull (rx_fifo0_wrfull),
        .rx_fifo_rdempty(rx_fifo0_rdempty),
        .rx_fifo_rdusedw(rx_fifo0_rdusedw),
        .rx_error       (rx_fifo0_overflow),
        //------------ uart0 param.-----------
        .uart_check_flag(uart0_check_flag),
        .uart_stop_flag (uart0_stop_flag),
        .uart_data_flag (uart0_data_flag),
        .uart_baud_rate (uart0_baud_rate),
        //------------ uart0 interface -------
        .uart_tx        (uart0_tx),
        .uart_rx        (uart0_rx)     
       );


//------------------------- output -----------------------------
/*
always @( * )
begin
       if(addr_reg == `UART0_CTRL)   data_out = {27'h0,uart0_check_flag,uart0_stop_flag,uart0_data_flag};
  else if(addr_reg == `UART0_BAUD)   data_out = {18'h0,uart0_baud_rate};
  //else if(addr_reg == `GPIO_CTRL)    data_out = {8'h0,p_mode};
  else if(addr_reg == `RX_FIFO0)     data_out = {24'h0,rx_fifo0_q};
  else if(addr_reg == `FIFO0_SZE)    data_out = {8'h0,tx_fifo0_wrusedw[7:0],8'h0,rx_fifo0_rdusedw[7:0]};
  else if(addr_reg == `FIFO0_STATUS) data_out = {24'h0,tx_fifo0_overflow,rx_fifo0_overflow,tx_fifo0_wrfull,tx_fifo0_rdempty,rx_fifo0_wrfull,rx_fifo0_rdempty};
  //else if(addr_reg == `GPIO_STATUS)  data_out = {8'h0,gpio_state};
  //else if(addr_reg == `GPIO_OUT)     data_out = {8'h0,gpio_out};
  else                               data_out = 32'h0;
end
*/
//----------------------- timer interrupt --------------------------
reg [31:0] mtimecmp;
reg [31:0] mtime;
reg        mcountstar;
reg        time_interrupt;

reg [31:0] SDAddr_r;
reg [31:0] SDCounts_r;
reg [31:0] DestAddr_r;
reg [31:0] DMAEN_r;

assign SDAddr   = SDAddr_r  ;
assign SDCounts = SDCounts_r;
assign DestAddr = DestAddr_r;
assign DMAEN    = DMAEN_r   ;

always @(posedge clk or negedge rst)
begin
  if(!rst) begin
     mtimecmp   <= 32'hffffffff; 
     mcountstar <= 1'b0;

     SDAddr_r   <= 32'd0;
     SDCounts_r <= 32'd0;
     DestAddr_r <= 32'd0;
     DMAEN_r    <= 32'd0;
  end
  else begin
    if(wr && (addr == `MTIMECMP))    mtimecmp     <= data_in;  
    if(wr && (addr == `MCOUNTSTAR))  mcountstar   <= data_in[0];

    if(wr && (addr == `SDStartAddr))  SDAddr_r    <= data_in;
    if(wr && (addr == `SDCounts))     SDCounts_r  <= data_in;
    if(wr && (addr == `DestAddr))     DestAddr_r  <= data_in;
    if(wr && (addr == `DMAEN))        DMAEN_r     <= data_in;
  end
end

always @(posedge clk or negedge rst) begin
  if(!rst) begin
    mtime       <= 32'h0;
  end
  else begin
    if(mcountstar) begin
      if(&mtime)                    //mtime == 32'hffffffff,停止计数
        mtime     <= mtime;
      else mtime  <= mtime + 1'b1;
    end
    else begin
      mtime     <= 32'h0;
    end
  end
end

always @(posedge clk or negedge rst) begin
  if(!rst) begin
    time_interrupt    <= 1'b0;
  end
  else begin
    if(mtime >= mtimecmp) 
      time_interrupt  <= 1'b1;
    else
      time_interrupt  <= 1'b0;            //在开启下次时钟中断前需要先关闭 mcountstar
  end
end
assign timer          = time_interrupt;



// ila_0 your_instance_name (
// 	.clk(clk), // input wire clk


// 	.probe0(gpio_out), // input wire [31:0]  probe0  
// 	.probe1(gpio_ctrl), // input wire [31:0]  probe1 
// 	.probe2(gpio_wdata), // input wire [31:0]  probe2
//   .probe3(addr),
//   .probe4(wr)
// );

endmodule
