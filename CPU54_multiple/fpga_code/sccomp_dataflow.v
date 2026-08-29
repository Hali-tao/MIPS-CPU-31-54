`timescale 1ns / 1ps

// 最顶层模块
module sccomp_dataflow(
    input clk_in,
    input reset,
    // output [31:0] inst,
    // output [31:0] pc
    output [7:0] o_seg,
    output [7:0] o_sel
    );

// 实例化cpu dmem imem三个模块

// cpu
wire [31:0] pc_out;
wire [31:0] dm_addr;
wire pc_update;
// imem
wire [31:0] im_addr;
wire [31:0] im_inst;
// dmem
wire dm_ena;
wire [3:0] dm_we;
wire dm_re;
wire [31:0] dm_map_addr;
wire [31:0] dm_wdata;
wire [31:0] dm_rdata;

assign im_addr = pc_out - 32'h00400000;
assign dm_map_addr = dm_addr - 32'h10010000;

// assign inst = im_inst;

    // reg [31:0] pc_out_reg;

    // always @(posedge clk_in or posedge reset) begin
    //     if (reset) begin
    //         pc_out_reg <= 32'h0040_0000;
    //     end else if (pc_update) begin
    //         pc_out_reg <= pc_out;
    //     end
    // end
    // assign pc = pc_out_reg;

cpu sccpu(
    // inputs
    .clk(clk_in_div),
    .ena(1'b1),
    .rst(reset),
    .im_inst(im_inst),
    .dm_rdata(dm_rdata),
    .intr(1'b0),

    // outputs
    .dm_ena(dm_ena),
    .dm_we(dm_we),
    .dm_re(dm_re),
    .dm_addr(dm_addr),
    .dm_wdata(dm_wdata),
    .pc_out(pc_out),
    .update_pc(pc_update)
);

imem im(
    // input
    .addr(im_addr[12:2]),
    // output
    .inst(im_inst)
);


dmem dm(
    // inputs
    .clk(clk_in_div),
    .ena(dm_ena),
    .re(dm_re),
    .we(dm_we),
    .addr(dm_map_addr[12:2]),
    .wdata(dm_wdata),
    // output
    .rdata(dm_rdata)
);

seg7x16 seg(
    .clk(clk_in),
    .reset(reset),
    .cs(1'b1),
    .i_data(im_inst),
    .o_seg(o_seg),
    .o_sel(o_sel)
);

divider div(
    .clk(clk_in),
    .rst(reset),
    .clk_out(clk_in_div)
);
endmodule
