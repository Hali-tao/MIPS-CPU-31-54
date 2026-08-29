`timescale 1ns / 1ps

module hilo_reg(
    input clk,                  // 时钟信号
    input rst,                  // 复位信号（高电平有效）
    input hi_we,                // HI 寄存器写使能
    input lo_we,                // LO 寄存器写使能
    input [31:0] hi_in,         // 写入 HI 的数据
    input [31:0] lo_in,         // 写入 LO 的数据
    
    output [31:0] hi_out,       // 读出 HI 的数据
    output [31:0] lo_out        // 读出 LO 的数据
);

    // 内部定义两个独立的 32 位寄存器
    reg [31:0] hi_reg;
    reg [31:0] lo_reg;

    // ==========================================
    // 时序逻辑：时钟上升沿写入
    // ==========================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位时将 HI 和 LO 寄存器清零
            hi_reg <= 32'b0;
            lo_reg <= 32'b0;
        end 
        else begin
            // 如果 HI 写使能有效，锁存输入数据
            if (hi_we) begin
                hi_reg <= hi_in;
            end
            
            // 如果 LO 写使能有效，锁存输入数据
            if (lo_we) begin
                lo_reg <= lo_in;
            end
        end
    end

    // ==========================================
    // 组合逻辑：持续读出数据
    // ==========================================
    assign hi_out = hi_reg;
    assign lo_out = lo_reg;

endmodule