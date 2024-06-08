module interrupt_ctrl(
    clk,
    rst_n,

    key1,
    key2,
    key3,
    ReadSD_finish,

    int_index,
    int_mstatus_mie,
    mret_en,
    trap_entry_en,
    trap_exit_en,

    pc_insr,

    timer
);
input           clk;
input           rst_n;

input           key1;
input           key2;
input           key3;
input           ReadSD_finish;

input           int_mstatus_mie;
input           mret_en;
output [3:0]    int_index;
output          trap_entry_en;
output          trap_exit_en;

input           pc_insr; 

input           timer;

wire            trap_normal;
wire            trap_bxx;
wire   [3:0]    int_index_normal;
reg             trap_bxx_r, pc_insr_r;
reg    [3:0]    int_index_r;

reg             key1_r, key2_r, key3_r;
reg             key1_r2, key2_r2, key3_r2;
reg             key1_r3, key2_r3, key3_r3;
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        key1_r  <= 1'b1;
        key2_r  <= 1'b1;
        key3_r  <= 1'b1;
        key1_r2 <= 1'b1;
        key2_r2 <= 1'b1;
        key3_r2 <= 1'b1;
        key1_r3 <= 1'b1;
        key2_r3 <= 1'b1;
        key3_r3 <= 1'b1;

        pc_insr_r <= 1'b0;
    end
    else begin
        key1_r  <= key1;
        key2_r  <= key2;
        key3_r  <= key3;
        key1_r2 <= key1_r;
        key2_r2 <= key2_r;
        key3_r2 <= key3_r;
        key1_r3 <= key1_r2;
        key2_r3 <= key2_r2;
        key3_r3 <= key3_r2;

        pc_insr_r <= pc_insr;
    end
end
wire   int1             = ~key1_r2 & key1_r3;  //test key1 No.15 interrupt
wire   int2             = ~key2_r2 & key2_r3;  //test key2 No.12 interrupt
wire   int3             = ~key3_r2 & key3_r3;  //test key2 No.8 interrupt

assign trap_normal      = int_mstatus_mie ? (int1 | int2 | int3 | ReadSD_finish | timer) : 1'b0;

//trap_bxx : if pc_insr & trap_normal is high, delay trap_normal to the posedge clk of pc_insr
always @(posedge clk or negedge rst_n) begin
    if(~rst_n) trap_bxx_r <= 1'b0;
    else begin
        if(pc_insr & trap_normal)
            trap_bxx_r <= 1'b1;
        else if(pc_insr)
            trap_bxx_r <= trap_bxx_r;
        else
            trap_bxx_r <= 1'b0;
    end
end
assign trap_bxx         = trap_bxx_r & ( (~pc_insr) & pc_insr_r );

always @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        int_index_r <= 4'd0;
    end
    else begin
        if(pc_insr & trap_normal) int_index_r <= int_index_normal;
        else if(pc_insr)
            int_index_r <= int_index_r;
        else int_index_r <= 4'd0;
    end
end

assign trap_entry_en    = pc_insr ? 1'b0 : (trap_bxx | trap_normal);
assign trap_exit_en     = mret_en;
//assign int_index        = int1 ? 4'b1111 : int2 ? 4'b1100 : int3 ? 4'b1000 : 4'b0;
assign int_index_normal = ({4{int1}} & 4'b1111) | ({4{int2}} & 4'b1100) 
                        | ({4{int3}} & 4'b1000) | ({4{timer}} & 4'b0100)
                        | ({4{ReadSD_finish}} & 4'b1110);
assign int_index        = int_index_normal | int_index_r;


endmodule