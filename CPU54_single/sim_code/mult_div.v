`timescale 1ns / 1ps

module mult_div(
    input [31:0] a,              // 对应 MIPS 指令中的 rs 寄存器数据
    input [31:0] b,              // 对应 MIPS 指令中的 rt 寄存器数据
    input [1:0] mult_div_op,     // 控制信号: 00-mult, 01-multu, 10-div, 11-divu
    
    output reg [31:0] hi_out,    // 输出给 HI 寄存器的组合逻辑数据
    output reg [31:0] lo_out     // 输出给 LO 寄存器的组合逻辑数据
);

    // 内部 64 位寄存器，用于暂存乘法的全精度 64 位结果
    reg [63:0] mult_res;

    always @(*) begin
        // 赋初值，防止生成非预期的锁存器 (Latch)
        hi_out   = 32'b0;
        lo_out   = 32'b0;
        mult_res = 64'b0;

        case (mult_div_op)
            // ==========================================
            // 1. mult: 有符号乘法
            // ==========================================
            2'b00: begin
                // 使用 $signed() 强制 Verilog 进行有符号符号位扩展乘法
                mult_res = $signed(a) * $signed(b);
                hi_out   = mult_res[63:32]; // 高 32 位存入 HI
                lo_out   = mult_res[31:0];  // 低 32 位存入 LO
            end

            // ==========================================
            // 2. multu: 无符号乘法
            // ==========================================
            2'b01: begin
                // Verilog 默认进行无符号乘法
                mult_res = a * b;
                hi_out   = mult_res[63:32];
                lo_out   = mult_res[31:0];
            end

            // ==========================================
            // 3. div: 有符号除法
            // ==========================================
            2'b10: begin
                if (b != 32'b0) begin
                    // $signed 进行有符号整除与求余
                    lo_out = $signed(a) / $signed(b); // 商 -> LO
                    hi_out = $signed(a) % $signed(b); // 余数 -> HI
                end else begin
                    // 容错处理：如果除数为 0，MIPS 未定义行为。
                    // 硬件上通常将其清零，防止 ModelSim 仿真时因为除0导致报错挂起。
                    lo_out = 32'b0;
                    hi_out = 32'b0;
                end
            end

            // ==========================================
            // 4. divu: 无符号除法
            // ==========================================
            2'b11: begin
                if (b != 32'b0) begin
                    lo_out = a / b; // 商 -> LO
                    hi_out = a % b; // 余数 -> HI
                end else begin
                    lo_out = 32'b0;
                    hi_out = 32'b0;
                end
            end

            default: begin
                hi_out = 32'b0;
                lo_out = 32'b0;
            end
        endcase
    end

endmodule