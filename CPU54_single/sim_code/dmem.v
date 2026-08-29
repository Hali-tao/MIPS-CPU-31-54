`timescale 1ns / 1ps

module dmem(
    input clk,
    input ena,
    input re,
    input [3:0] we,          // 【修改】从 1 位改为 4 位字节写使能信号
    input [10:0] addr,
    input [31:0] wdata,
    output [31:0] rdata
);

reg [31:0] dm [2047:0];        // 保持你原有的 32 个字大小

// 读取用异步（保持原样，总是读出完整的 32 位，由 CPU 内部去截取和扩展）
assign rdata = (ena && re && (we == 4'b0000)) ? dm[addr] : 32'bz;

// 写入用同步【修改】：根据 4 位 we 信号，精细化写入对应的字节
always @(negedge clk) begin
    if(ena) begin
        if (we[0]) dm[addr][7:0]   <= wdata[7:0];   // 写第 0 字节
        if (we[1]) dm[addr][15:8]  <= wdata[15:8];  // 写第 1 字节
        if (we[2]) dm[addr][23:16] <= wdata[23:16]; // 写第 2 字节
        if (we[3]) dm[addr][31:24] <= wdata[31:24]; // 写第 3 字节
    end
end

endmodule