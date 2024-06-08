`include "risc_v_defines.vh"

module EX (

    input                                clk,
    input                                rst_n,

    input   [`DECINFO_M_D_WIDTH-1:0]     muldiv_info_bus,
    input   [`rv32_XLEN-1:0]             Op1,
    input   [`rv32_XLEN-1:0]             Op2,
    input                                Addcin,
    input                                MUL_sig,
    input   [`EN_Wid-1 : 0]              Op_En,

    output  [`rv32_XLEN-1:0]             EX_res,
    output                               div_alu_time,
    output  [`rv32_XLEN-1:0]             addr_res,

    input   [`DECINFO_CSR_WIDTH-1:0]     csr_info_bus,
    input                                d_hready
);

//-----------------------------------ALU RESULT-----------------------------------
wire    [`rv32_XLEN-1:0] add_res;
wire    [`rv32_XLEN-1:0] add_op1;
wire    [`rv32_XLEN-1:0] add_op2;
wire                     add_cin;
assign add_op1              =   Op_En[`add_en] ? Op1 : `rv32_XLEN'b0;
assign add_op2              =   Op_En[`add_en] ? Op2 : `rv32_XLEN'b0;
assign add_cin              =   Op_En[`add_en] ? Addcin : 1'b0;
assign add_res              =   add_op1 + add_op2 + add_cin;

wire                     com_res;
wire    [`rv32_XLEN-1:0] com_op1;
wire    [`rv32_XLEN-1:0] com_op2;
assign com_op1              =   Op_En[`com_en] ? Op1 : `rv32_XLEN'b0;
assign com_op2              =   Op_En[`com_en] ? Op2 : `rv32_XLEN'b0;
assign com_res              =   Op_En[`com_sign] ? ($signed(Op1) < $signed(Op2)) : ($unsigned(Op1) < $unsigned(Op2)) ;

wire    [`rv32_XLEN-1:0] and_res;
wire    [`rv32_XLEN-1:0] and_op1;
wire    [`rv32_XLEN-1:0] and_op2;
assign and_op1              =   Op_En[`and_en] ? Op1 : `rv32_XLEN'b0;
assign and_op2              =   Op_En[`and_en] ? Op2 : `rv32_XLEN'b0;
assign and_res              =   and_op1 & and_op2;

wire    [`rv32_XLEN-1:0] or_res;
wire    [`rv32_XLEN-1:0] or_op1;
wire    [`rv32_XLEN-1:0] or_op2;
assign or_op1               =   Op_En[`or_en ] ? Op1 : `rv32_XLEN'b0;
assign or_op2               =   Op_En[`or_en ] ? Op2 : `rv32_XLEN'b0;
assign or_res               =   or_op1 | or_op2;

wire    [`rv32_XLEN-1:0] xor_res;
wire    [`rv32_XLEN-1:0] xor_op1;
wire    [`rv32_XLEN-1:0] xor_op2;
assign xor_op1              =   Op_En[`xor_en] ? Op1 : `rv32_XLEN'b0;
assign xor_op2              =   Op_En[`xor_en] ? Op2 : `rv32_XLEN'b0;
assign xor_res              =   xor_op1 ^ xor_op2;

//逻辑移位运算结果，如果是左移，则将op1反转后进行右�?
wire    [`rv32_XLEN-1:0] lgc_res;
wire    [`rv32_XLEN-1:0] lgc_op1;
wire    [4:0]            lgc_op2;
wire    [`rv32_XLEN-1:0] lgc_op1_re;            //逻辑左移，将输入先反转，依旧进行右移操作
wire    [`rv32_XLEN-1:0] lgc_op;                //对lgc_op1和lgc_op1_re进行选择
wire    [`rv32_XLEN-1:0] lgc_res1;
wire    [`rv32_XLEN-1:0] lgc_res2;
wire    [`rv32_XLEN-1:0] lgc_res3;
wire    [`rv32_XLEN-1:0] lgc_res3_re;
assign lgc_op1              =   Op_En[`lgc_en] ? Op1 : `rv32_XLEN'b0;
assign lgc_op2              =   Op_En[`lgc_en] ? Op2[4:0] : `rv32_XLEN'b0;
assign lgc_op1_re           =   Op_En[`lgcl_en] ? { Op1[00],Op1[01],Op1[02],Op1[03],Op1[04],
                                                    Op1[05],Op1[06],Op1[07],Op1[08],Op1[09],
                                                    Op1[10],Op1[11],Op1[12],Op1[13],Op1[14],
                                                    Op1[15],Op1[16],Op1[17],Op1[18],Op1[19],
                                                    Op1[20],Op1[21],Op1[22],Op1[23],Op1[24],
                                                    Op1[25],Op1[26],Op1[27],Op1[28],Op1[29],
                                                    Op1[30],Op1[31] } : `rv32_XLEN'b0;
assign lgc_op               =   Op_En[`lgcl_en] ? lgc_op1_re : lgc_op1;
assign lgc_res1             =   ( {`rv32_XLEN{~(|lgc_op2[4:3])}} & lgc_op )
                              | ( {`rv32_XLEN{~lgc_op2[4] & lgc_op2[3]}} & {8'b0, lgc_op[31:8]} )
                              | ( {`rv32_XLEN{lgc_op2[4] & ~lgc_op2[3]}} & {16'b0, lgc_op[31:16]} )
                              | ( {`rv32_XLEN{&lgc_op2[4:3]}} & {24'b0, lgc_op[31:24]} );
assign lgc_res2             =   lgc_op2[2] ? {4'b0,lgc_res1[31:4]} : lgc_res1;
assign lgc_res3             =   ( {`rv32_XLEN{~(|lgc_op2[1:0])}} & lgc_res2 )     
                              | ( {`rv32_XLEN{~lgc_op2[1] & lgc_op2[0]}} & {1'b0, lgc_res2[31:1]} ) 
                              | ( {`rv32_XLEN{lgc_op2[1] & ~lgc_op2[0]}} & {2'b0, lgc_res2[31:2]} )
                              | ( {`rv32_XLEN{&lgc_op2[1:0]}} & {3'b0, lgc_res2[31:3]} );
assign lgc_res3_re          =   { lgc_res3[00],lgc_res3[01],lgc_res3[02],lgc_res3[03],lgc_res3[04],
                                  lgc_res3[05],lgc_res3[06],lgc_res3[07],lgc_res3[08],lgc_res3[09],
                                  lgc_res3[10],lgc_res3[11],lgc_res3[12],lgc_res3[13],lgc_res3[14],
                                  lgc_res3[15],lgc_res3[16],lgc_res3[17],lgc_res3[18],lgc_res3[19],
                                  lgc_res3[20],lgc_res3[21],lgc_res3[22],lgc_res3[23],lgc_res3[24],
                                  lgc_res3[25],lgc_res3[26],lgc_res3[27],lgc_res3[28],lgc_res3[29],
                                  lgc_res3[30],lgc_res3[31] };
assign lgc_res              =   Op_En[`lgcl_en] ? lgc_res3_re : lgc_res3;

//算术右移
wire    [`rv32_XLEN-1:0] alur_op1;
wire    [4:0]            alur_op2;
wire    [`rv32_XLEN-1:0] alur_res;
wire    [`rv32_XLEN-1:0] alur_res1;
wire    [`rv32_XLEN-1:0] alur_res2;
assign alur_op1             =   Op_En[`alur_en] ? Op1 : `rv32_XLEN'b0;
assign alur_op2             =   Op_En[`alur_en] ? Op2[4:0] : `rv32_XLEN'b0;
assign alur_res1            =   ( {`rv32_XLEN{~(|alur_op2[4:3])}} & alur_op1 )
                              | ( {`rv32_XLEN{(~alur_op2[4] & alur_op2[3])}} & {{8{alur_op1[31]}}, alur_op1[31:8]} )
                              | ( {`rv32_XLEN{alur_op2[4] & ~alur_op2[3]}} & {{16{alur_op1[31]}}, alur_op1[31:16]} )
                              | ( {`rv32_XLEN{&alur_op2[4:3]}} & {{24{alur_op1[31]}}, alur_op1[31:24]} );
assign alur_res2            =   alur_op2[2] ? {{4{alur_op1[31]}}, alur_res1[31:4]} : alur_res1;
assign alur_res             =   ( {`rv32_XLEN{~(|alur_op2[1:0])}} & alur_res2 )
                              | ( {`rv32_XLEN{~alur_op2[1] & alur_op2[0]}} & {alur_op1[31], alur_res2[31:1]} )
                              | ( {`rv32_XLEN{alur_op2[1] & ~alur_op2[0]}} & {{2{alur_op1[31]}}, alur_res2[31:2]} )
                              | ( {`rv32_XLEN{&alur_op2[1:0]}} & {{3{alur_op1[31]}}, alur_res2[31:3]} );   

wire    csr_en              = |csr_info_bus;
wire    [`rv32_XLEN-1:0] csr_res;
assign  csr_res             =   Op2;

wire    [`rv32_XLEN-1:0] ALU_res;
assign ALU_res              =   ({`rv32_XLEN{Op_En[`add_en]}} & add_res) | (Op_En[`com_en] & com_res) | ({`rv32_XLEN{Op_En[`and_en]}} & and_res)
                              | ({`rv32_XLEN{Op_En[`or_en ]}} & or_res ) | ({`rv32_XLEN{Op_En[`xor_en]}} & xor_res ) | ({`rv32_XLEN{Op_En[`lgc_en]}} & lgc_res )
                              | ({`rv32_XLEN{Op_En[`alur_en]}} & alur_res) | ({`rv32_XLEN{csr_en}} & csr_res);




//--------------------------------------mul result-----------------------------------
wire    [`rv32_XLEN-1:0] mul_op1;
wire    [`rv32_XLEN-1:0] mul_op2;
wire    [`rv32_XLEN-1:0] mul_res;
wire    [63:0]           mul_rd;
wire    [63:0]           mul_rd_sig;
//MUL_sig :0表示结果为正数�??1表示负数
assign mul_op1              =   muldiv_info_bus[`DECINFO_MUL] ? Op1 : `rv32_XLEN'b0;
assign mul_op2              =   muldiv_info_bus[`DECINFO_MUL] ? Op2 : `rv32_XLEN'b0;
assign mul_rd               =   mul_op1 * mul_op2;
assign mul_rd_sig           =  ~mul_rd + 1'b1;
assign mul_res              =   muldiv_info_bus[`DECINFO_MD_MUL] ? mul_rd[31:0] : MUL_sig ? mul_rd_sig[63:32] : mul_rd[63:32];


//--------------------------------------div result-----------------------------------
wire    [`rv32_XLEN:0]  a_opuns;
wire    [`rv32_XLEN:0]  b_opuns;
wire                    DIVsign;
wire    [5:0]           N1;
wire    [5:0]           N2;

assign          DIVsign     =   muldiv_info_bus[`DECINFO_MD_DIV] | muldiv_info_bus[`DECINFO_MD_REM];
assign          a_opuns     =   (DIVsign & Op1[`rv32_XLEN-1]) ? $unsigned(~Op1 + 1'b1) : Op1;   //根据输入符号位，
assign          b_opuns     =   (DIVsign & Op2[`rv32_XLEN-1]) ? $unsigned(~Op2 + 1'b1) : Op2;   //操作数转换为正数

//计算输入数据b�?高位1的位置，第一层�?�择信号，第二层，第三层，第四层
wire    [5:0]   sel1_1,sel1_2,sel1_3,sel1_4,sel1_5,sel1_6,sel1_7,sel1_8;  
wire    [5:0]   sel1_9,sel1_10,sel1_11,sel1_12,sel1_13,sel1_14,sel1_15,sel1_16;
wire    [5:0]   sel2_1,sel2_2,sel2_3,sel2_4;
wire    [5:0]   sel2_5,sel2_6,sel2_7,sel2_8;
wire    [5:0]   sel3_1,sel3_2;
wire    [5:0]   sel3_3,sel3_4;
wire    [5:0]   sel4_1,sel4_2;

//第二层�?�择控制信号，第三层，第四层,5
wire            contral2_1, contral2_2, contral2_3, contral2_4;
wire            contral2_5, contral2_6, contral2_7, contral2_8;
wire            contral3_1, contral3_2;
wire            contral3_3, contral3_4;
wire            contral4_1, contral4_2;
wire            contral5_1;  

assign          sel1_1      =   b_opuns[31] ? 5'b0 : 6'b1;   
assign          sel1_2      =   b_opuns[29] ? 6'd2 : 6'd3;
assign          sel1_3      =   b_opuns[27] ? 6'd4 : 6'd5;
assign          sel1_4      =   b_opuns[25] ? 6'd6 : 6'd7;
assign          sel1_5      =   b_opuns[23] ? 6'd8 : 6'd9;
assign          sel1_6      =   b_opuns[21] ? 6'd10 : 6'd11;
assign          sel1_7      =   b_opuns[19] ? 6'd12 : 6'd13;
assign          sel1_8      =   b_opuns[17] ? 6'd14 : 6'd15;
assign          sel1_9      =   b_opuns[15] ? 6'd16 : 6'd17;
assign          sel1_10     =   b_opuns[13] ? 6'd18 : 6'd19;
assign          sel1_11     =   b_opuns[11] ? 6'd20 : 6'd21;
assign          sel1_12     =   b_opuns[09] ? 6'd22 : 6'd23;
assign          sel1_13     =   b_opuns[07] ? 6'd24 : 6'd25;
assign          sel1_14     =   b_opuns[05] ? 6'd26 : 6'd27;
assign          sel1_15     =   b_opuns[03] ? 6'd28 : 6'd29;
assign          sel1_16     =   b_opuns[01] ? 6'd30 : 6'd31;

assign          contral2_1  =   b_opuns[31] | b_opuns[30];
assign          contral2_2  =   b_opuns[27] | b_opuns[26];
assign          contral2_3  =   b_opuns[23] | b_opuns[22];
assign          contral2_4  =   b_opuns[19] | b_opuns[18];
assign          contral2_5  =   b_opuns[15] | b_opuns[14];
assign          contral2_6  =   b_opuns[11] | b_opuns[10];
assign          contral2_7  =   b_opuns[07] | b_opuns[06];
assign          contral2_8  =   b_opuns[03] | b_opuns[02];

assign          sel2_1      =   contral2_1 ? sel1_1 : sel1_2;
assign          sel2_2      =   contral2_2 ? sel1_3 : sel1_4;
assign          sel2_3      =   contral2_3 ? sel1_5 : sel1_6;
assign          sel2_4      =   contral2_4 ? sel1_7 : sel1_8;
assign          sel2_5      =   contral2_5 ? sel1_9 : sel1_10;
assign          sel2_6      =   contral2_6 ? sel1_11 : sel1_12;
assign          sel2_7      =   contral2_7 ? sel1_13 : sel1_14;
assign          sel2_8      =   contral2_8 ? sel1_15 : sel1_16;

assign          contral3_1  =   contral2_1 | b_opuns[29] | b_opuns[28];
assign          contral3_2  =   contral2_3 | b_opuns[21] | b_opuns[20];
assign          contral3_3  =   contral2_5 | b_opuns[13] | b_opuns[12];
assign          contral3_4  =   contral2_7 | b_opuns[05] | b_opuns[04];

assign          sel3_1      =   contral3_1 ? sel2_1 : sel2_2;
assign          sel3_2      =   contral3_2 ? sel2_3 : sel2_4;
assign          sel3_3      =   contral3_3 ? sel2_5 : sel2_6;
assign          sel3_4      =   contral3_4 ? sel2_7 : sel2_8;

assign          contral4_1  =   contral3_1 | contral2_2 | b_opuns[24] | b_opuns[25];
assign          contral4_2  =   contral3_3 | contral2_6 | b_opuns[8] | b_opuns[9];

assign          sel4_1      =   contral4_1 ? sel3_1 : sel3_2;
assign          sel4_2      =   contral4_2 ? sel3_3 : sel3_4;

assign          contral5_1  =   contral4_1 | contral3_2 | contral2_4 | b_opuns[17] | b_opuns[16];
assign          N2          =   contral5_1 ? sel4_1 : sel4_2;

//计算输入数据a�?高位1的位置，第一层�?�择信号，第二层，第三层，第四层
wire    [5:0]   asel1_1,asel1_2,asel1_3,asel1_4,asel1_5,asel1_6,asel1_7,asel1_8;  
wire    [5:0]   asel1_9,asel1_10,asel1_11,asel1_12,asel1_13,asel1_14,asel1_15,asel1_16;
wire    [5:0]   asel2_1,asel2_2,asel2_3,asel2_4;
wire    [5:0]   asel2_5,asel2_6,asel2_7,asel2_8;
wire    [5:0]   asel3_1,asel3_2;
wire    [5:0]   asel3_3,asel3_4;
wire    [5:0]   asel4_1,asel4_2;

//第二层�?�择控制信号，第三层，第四层,5
wire            acontral2_1, acontral2_2, acontral2_3, acontral2_4;
wire            acontral2_5, acontral2_6, acontral2_7, acontral2_8;
wire            acontral3_1, acontral3_2;
wire            acontral3_3, acontral3_4;
wire            acontral4_1, acontral4_2;
wire            acontral5_1;  

assign          asel1_1      =   a_opuns[31] ? 6'b0 : 6'b1;   
assign          asel1_2      =   a_opuns[29] ? 6'd2 : 6'd3;
assign          asel1_3      =   a_opuns[27] ? 6'd4 : 6'd5;
assign          asel1_4      =   a_opuns[25] ? 6'd6 : 6'd7;
assign          asel1_5      =   a_opuns[23] ? 6'd8 : 6'd9;
assign          asel1_6      =   a_opuns[21] ? 6'd10 : 6'd11;
assign          asel1_7      =   a_opuns[19] ? 6'd12 : 6'd13;
assign          asel1_8      =   a_opuns[17] ? 6'd14 : 6'd15;
assign          asel1_9      =   a_opuns[15] ? 6'd16 : 6'd17;
assign          asel1_10     =   a_opuns[13] ? 6'd18 : 6'd19;
assign          asel1_11     =   a_opuns[11] ? 6'd20 : 6'd21;
assign          asel1_12     =   a_opuns[09] ? 6'd22 : 6'd23;
assign          asel1_13     =   a_opuns[07] ? 6'd24 : 6'd25;
assign          asel1_14     =   a_opuns[05] ? 6'd26 : 6'd27;
assign          asel1_15     =   a_opuns[03] ? 6'd28 : 6'd29;
assign          asel1_16     =   a_opuns[01] ? 6'd30 : 6'd31;


assign          acontral2_1 =   a_opuns[31] | a_opuns[30];
assign          acontral2_2 =   a_opuns[27] | a_opuns[26];
assign          acontral2_3 =   a_opuns[23] | a_opuns[22];
assign          acontral2_4 =   a_opuns[19] | a_opuns[18];
assign          acontral2_5 =   a_opuns[15] | a_opuns[14];
assign          acontral2_6 =   a_opuns[11] | a_opuns[10];
assign          acontral2_7 =   a_opuns[07] | a_opuns[06];
assign          acontral2_8 =   a_opuns[03] | a_opuns[02];

assign          asel2_1     =   acontral2_1 ? asel1_1 : asel1_2;
assign          asel2_2     =   acontral2_2 ? asel1_3 : asel1_4;
assign          asel2_3     =   acontral2_3 ? asel1_5 : asel1_6;
assign          asel2_4     =   acontral2_4 ? asel1_7 : asel1_8;
assign          asel2_5     =   acontral2_5 ? asel1_9 : asel1_10;
assign          asel2_6     =   acontral2_6 ? asel1_11 : asel1_12;
assign          asel2_7     =   acontral2_7 ? asel1_13 : asel1_14;
assign          asel2_8     =   acontral2_8 ? asel1_15 : asel1_16;

assign          acontral3_1 =   acontral2_1 | a_opuns[29] | a_opuns[28];
assign          acontral3_2 =   acontral2_3 | a_opuns[21] | a_opuns[20];
assign          acontral3_3 =   acontral2_5 | a_opuns[13] | a_opuns[12];
assign          acontral3_4 =   acontral2_7 | a_opuns[05] | a_opuns[04];

assign          asel3_1     =   acontral3_1 ? asel2_1 : asel2_2;
assign          asel3_2     =   acontral3_2 ? asel2_3 : asel2_4;
assign          asel3_3     =   acontral3_3 ? asel2_5 : asel2_6;
assign          asel3_4     =   acontral3_4 ? asel2_7 : asel2_8;

assign          acontral4_1 =   acontral3_1 | acontral2_2 | a_opuns[24] | a_opuns[25];
assign          acontral4_2 =   acontral3_3 | acontral2_6 | a_opuns[8] | a_opuns[9];

assign          asel4_1     =   acontral4_1 ? asel3_1 : asel3_2;
assign          asel4_2     =   acontral4_2 ? asel3_3 : asel3_4;

assign          acontral5_1 =   acontral4_1 | acontral3_2 | acontral2_4 | a_opuns[17] | a_opuns[16];
assign          N1          =   acontral5_1 ? asel4_1 : asel4_2;

wire                     div_en1;
wire                     outsel;         //选择输出结果是商还是余数�?1表示结果为商
wire    [31:0]           quo;
wire    [31:0]           rem;
wire    [`rv32_XLEN-1:0] div_res;

//当d_hready为低时，说明L/S指令在等待数�?
//此时流水线停顿，ID阶段停在下一条指令，为避免多次写入下�?条指令，�?要暂停EXen_wb
assign  div_en1             =   d_hready ? muldiv_info_bus[`DECINFO_DIV] : 1'b0;

assign  outsel              =   muldiv_info_bus[`DECINFO_MD_DIV] | muldiv_info_bus[`DECINFO_MD_DIVU];
assign  div_res             =   outsel ? quo : rem;
EX_DIV EX_DIV_u (
    .clk                     (clk),
    .rst_n                   (rst_n),
    .a                       (Op1),              //被除�?
    .b                       (Op2),              //除数
    .sign                    (DIVsign),          //表示输入数是否为有符号数
    .div_en1                 (div_en1),               
    .quo_sign                (quo),
    .rem_sign                (rem),
    .alu_time                (div_alu_time),
    //finish                  (div_done)
    .a_opuns                 (a_opuns),
    .b_opuns                 (b_opuns),
    .N1                      (N1),
    .N2                      (N2)
);

assign EX_res               =    muldiv_info_bus[`DECINFO_MUL] ? mul_res : div_en1 ? div_res : ALU_res;
assign addr_res             =    add_res;

endmodule