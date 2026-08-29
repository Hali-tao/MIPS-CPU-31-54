`timescale 1ns / 1ps

module mult_div(
    input clk,                   // 引入时钟信号
    input reset,                 // 引入复位信号
    input [31:0] a,              // 对应 MIPS 指令中的 rs 寄存器数据
    input [31:0] b,              // 对应 MIPS 指令中的 rt 寄存器数据
    input [1:0] mult_div_op,     // 控制信号: 00-mult, 01-multu, 10-div, 11-divu
    input start,                 // 启动单次计算的控制脉冲信号
    
    output reg [31:0] hi_out,    // 输出给 HI 寄存器的组合逻辑数据
    output reg [31:0] lo_out,    // 输出给 LO 寄存器的组合逻辑数据
    output reg busy              // 输出给上层控制器的忙信号，表示计算未完成
);

    // =========================================================================
    // 1. 各个底层模块的连线定义
    // =========================================================================
    // 启动信号线
    wire start_mult  = (mult_div_op == 2'b00) && start;
    wire start_multu = (mult_div_op == 2'b01) && start;
    wire start_div   = (mult_div_op == 2'b10) && start;
    wire start_divu  = (mult_div_op == 2'b11) && start;

    // 忙碌状态线
    wire busy_mult;
    wire busy_multu;
    wire busy_div;
    wire busy_divu;

    // 结果数据线
    wire [63:0] z_mult;
    wire [63:0] z_multu;
    wire [31:0] q_div, r_div;
    wire [31:0] q_divu, r_divu;

    // =========================================================================
    // 2. 实例化四个底层多周期硬件模块
    // =========================================================================
    // 有符号乘法器 (5周期)
    MULT u_MULT (
        .clk(clk), .reset(reset), .a(a), .b(b), 
        .start(start_mult), .z(z_mult), .busy(busy_mult)
    );

    // 无符号乘法器 (5周期)
    MULTU u_MULTU (
        .clk(clk), .reset(reset), .a(a), .b(b), 
        .start(start_multu), .z(z_multu), .busy(busy_multu)
    );

    // 有符号除法器 (32周期)
    DIV u_DIV (
        .clock(clk), .reset(reset), .dividend(a), .divisor(b), 
        .start(start_div), .q(q_div), .r(r_div), .busy(busy_div)
    );

    // 无符号除法器 (32周期)
    DIVU u_DIVU (
        .clock(clk), .reset(reset), .dividend(a), .divisor(b), 
        .start(start_divu), .q(q_divu), .r(r_divu), .busy(busy_divu)
    );

    // =========================================================================
    // 3. 产生总的 busy 信号
    // =========================================================================
    // 当前执行模块在忙，或者接收到启动脉冲的那个周期，总忙信号都应拉高
    always @(*) begin
        busy = busy_mult | busy_multu | busy_div | busy_divu | start;
    end

    // =========================================================================
    // 4. 结果多路选择与输出逻辑
    // =========================================================================
    // 记录上一次发起的运算类型，用以在计算完成后正确保持输出结果
    reg [1:0] op_reg;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            op_reg <= 2'b00;
        end else if (start) begin
            op_reg <= mult_div_op;
        end
    end

    // 根据记录的运算类型，将各模块运算完成后的数据分流到 hi_out 和 lo_out
    always @(*) begin
        case (op_reg)
            2'b00: begin // mult
                hi_out = z_mult[63:32];
                lo_out = z_mult[31:0];
            end
            2'b01: begin // multu
                hi_out = z_multu[63:32];
                lo_out = z_multu[31:0];
            end
            2'b10: begin // div
                hi_out = r_div;  // 余数 -> HI
                lo_out = q_div;  // 商 -> LO
            end
            2'b11: begin // divu
                hi_out = r_divu; // 余数 -> HI
                lo_out = q_divu; // 商 -> LO
            end
            default: begin
                hi_out = 32'b0;
                lo_out = 32'b0;
            end
        endcase
    end

endmodule