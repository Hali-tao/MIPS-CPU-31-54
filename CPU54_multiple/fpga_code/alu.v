module alu(
    input [31:0] a,           // 输入操作数A
    input [31:0] b,           // 输入操作数B
    input [3:0] aluc,         // ALU控制信号，决定执行哪种运算
    output reg [31:0] r,      // 运算结果
    output zero,              // 零标志位，结果为0时置1
    output reg carry,         // 进位/借位标志位
    output reg negative,      // 负标志位，结果为负时置1
    output reg overflow       // 溢出标志位，有符号运算溢出时置1
);

    // 定义各种运算结果的连线
    wire [31:0] add_u, add_s, sub_u, sub_s;  // 加减法运算结果（无符号/有符号）
    wire [31:0] and_r, or_r, xor_r, nor_r;   // 逻辑运算结果
    wire [31:0] lui_r, sra_r, sll_r, srl_r;  // 移位和LUI运算结果
    wire [31:0] slt_r, sltu_r;               // 比较运算结果
    wire [4:0] shamt = a[4:0];

    // 基本算术运算
    assign add_u = a + b;                    // 无符号加法
    assign add_s = $signed(a) + $signed(b);  // 有符号加法
    assign sub_u = a - b;                    // 无符号减法
    assign sub_s = $signed(a) - $signed(b);  // 有符号减法
    
    // 逻辑运算
    assign and_r = a & b;                    // 按位与
    assign or_r  = a | b;                    // 按位或
    assign xor_r = a ^ b;                    // 按位异或
    assign nor_r = ~(a | b);                 // 按位或非
    
    // LUI指令：将立即数加载到高位
    assign lui_r = {b[15:0], 16'b0};         // b的低16位移到高16位，低16位补0

    // 移位运算
    assign sra_r = $signed(b) >>> shamt;         // 算术右移，保持符号位
    assign sll_r = b << shamt;                   // 逻辑左移/算术左移
    assign srl_r = b >> shamt;                   // 逻辑右移

    // 比较运算
    assign slt_r  = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;  // 有符号小于比较
    assign sltu_r = (a < b) ? 32'd1 : 32'd0;                    // 无符号小于比较

    // 结果选择模块：根据aluc控制信号选择对应的运算结果
    always @(*) begin
        casex(aluc)
            4'b0000: r = add_u; // Addu: 无符号加法
            4'b0010: r = add_s; // Add:  有符号加法
            4'b0001: r = sub_u; // Subu: 无符号减法
            4'b0011: r = sub_s; // Sub:  有符号减法
            4'b0100: r = and_r; // And:  按位与
            4'b0101: r = or_r;  // Or:   按位或
            4'b0110: r = xor_r; // Xor:  按位异或
            4'b0111: r = nor_r; // Nor:  按位或非
            4'b100x: r = lui_r; // Lui:  加载立即数到高位
            4'b1011: r = slt_r; // Slt:  有符号小于设置
            4'b1010: r = sltu_r;// Sltu: 无符号小于设置
            4'b1100: r = sra_r; // Sra:  算术右移
            4'b111x: r = sll_r; // Sll:  逻辑左移 / Sla: 算术左移
            4'b1101: r = srl_r; // Srl:  逻辑右移
            default: r = 32'b0; // 默认情况，输出0
        endcase
    end

    // zero 标志位生成逻辑
    // 对于SLT/SLTU指令：当a=b时结果为0，zero=1；当a≠b时结果为0或1，zero=0
    // 对于其他运算：当结果为0时zero=1
    assign zero = (aluc == 4'b1010 || aluc == 4'b1011) ? 
                  ((a == b) ? 1'b1 : 1'b0) :  // SLT/SLTU比较：a=b时zero=1
                  (r == 32'b0);               // 其他运算：结果r=0时zero=1

    // carry 标志位生成逻辑
    always @(*) begin
        casex(aluc)
            4'b0000: carry = (a + b < a);     // Addu: 无符号加法进位检测
            4'b0001: carry = (a < b);         // Subu: 无符号减法借位检测
            4'b1010: carry = (a < b);         // Sltu: 无符号比较，等同于借位
            4'b1100: begin                    // Sra: 算术右移进位
                if (a == 0) carry = 1'b0;     // 不移位时无进位
                else if (a > 32) carry = 1'b0;// 移位超过32位时无进位
                else carry = b[a-1];          // 正常移位，取被移出的位
            end
            4'b111x: begin                    // Sll: 逻辑左移进位
                if (a == 0) carry = 1'b0;     // 不移位时无进位
                else if (a > 32) carry = 1'b0;// 移位超过32位时无进位
                else carry = b[32 - a];       // 正常移位，取被移出的位
            end
            4'b1101: begin                    // Srl: 逻辑右移进位
                if (a == 0) carry = 1'b0;     // 不移位时无进位
                else if (a > 32) carry = 1'b0;// 移位超过32位时无进位
                else carry = b[a-1];          // 正常移位，取被移出的位
            end
            default: carry = 1'b0;            // 其他运算无进位
        endcase
    end

    // negative 标志位生成逻辑
    always @(*) begin
        casex(aluc)
            4'b0010, 4'b0011: negative = r[31]; // Add/Sub有符号运算：看结果符号位
            4'b1011: negative = slt_r[0];       // Slt有符号比较：结果直接作为符号
            default: negative = r[31];          // 其他运算：看结果最高位
        endcase
    end

    // overflow 标志位生成逻辑（仅对有符号加减法有效）
    always @(*) begin
        casex(aluc)
            // 有符号加法溢出：同号相加结果符号改变
            4'b0010: overflow = (a[31] == b[31]) && (r[31] != a[31]);
            // 有符号减法溢出：异号相减结果符号与a不同
            4'b0011: overflow = (a[31] != b[31]) && (r[31] != a[31]);
            default: overflow = 1'b0;           // 其他运算无溢出
        endcase
    end

endmodule