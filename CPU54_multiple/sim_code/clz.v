`timescale 1ns / 1ps

module clz(
    input [31:0] in,      // 输入的 32 位数据（对应 rs 寄存器的数据）
    output reg [31:0] out // 输出前导零的个数（写回 rd 寄存器）
);

    integer i;
    reg found;

    always @(*) begin
        out = 32'd32;    // 默认值：如果输入全为 0，则有 32 个前导零
        found = 1'b0;    // 标志位：是否已经找到了第一个 1
        
        // 从最高位（bit 31）向最低位（bit 0）进行扫描
        for (i = 31; i >= 0; i = i - 1) begin
            if (!found && in[i]) begin
                out = 31 - i;  // 例如：bit 31 为 1，则前导零为 31-31 = 0 个
                found = 1'b1;  // 标记已找到，后续的 1 不再触发修改
            end
        end
    end

endmodule