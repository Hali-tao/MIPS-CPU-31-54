`timescale 1ns / 1ps

// 最顶层模块
module sccomp_dataflow(
    input clk_in,
    input reset,
    output [31:0] inst,
    output [31:0] pc
    );

// 实例化cpu dmem imem三个模块

// cpu
wire [31:0] pc_out;
wire [31:0] dm_addr;
// imem
wire [31:0] im_addr;
wire [31:0] im_inst;
// dmem
wire dm_ena;
wire [3:0] dm_we;          // 【修改】改为4位字节写使能信号
wire dm_re;
wire [31:0] dm_map_addr;
wire [31:0] dm_wdata;
wire [31:0] dm_rdata;

assign im_addr = pc_out - 32'h00400000;
assign dm_map_addr = dm_addr - 32'h10010000;
assign pc = pc_out;
assign inst = im_inst;

cpu sccpu(
    // inputs
    .clk(clk_in),
    .ena(1'b1),
    .rst(reset),
    .inst(im_inst),
    .dm_rdata(dm_rdata),
    .intr(1'b0),

    // outputs
    .dm_ena(dm_ena),
    .dm_we(dm_we),
    .dm_re(dm_re),
    .dm_addr(dm_addr),
    .dm_wdata(dm_wdata),
    .pc_out(pc_out)
);

imem im(
    // input
    .addr(im_addr[12:2]),
    // output
    .inst(im_inst)
);

// 可变参数
// parameter FILE_NAME = "1_addi.hex.txt";
// imem_rom 
// #(
//     .IMEM_FILE(FILE_NAME)
// )
// im(
//     // input
//     .addr(im_addr[12:2]),
//     // output
//     .inst(im_inst)
// );

dmem dm(
    // inputs
    .clk(clk_in),
    .ena(dm_ena),
    .re(dm_re),
    .we(dm_we),
    .addr(dm_map_addr[12:2]),
    .wdata(dm_wdata),
    // output
    .rdata(dm_rdata)
);

endmodule
