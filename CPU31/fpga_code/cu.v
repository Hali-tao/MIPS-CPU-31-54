// 文件名：cu.v
// 功能：单周期MIPS CPU控制单元（集成ALU控制逻辑）
// 说明：输入指令的op和func字段，输出所有控制信号，直接驱动ALU、RF、DM、EXT等模块
module cu(
    input  [5:0] op,         // 输入：指令操作码 inst[31:26]
    input  [5:0] func,       // 输入：R型指令功能码 inst[5:0]
    output reg reg_write,    // 输出：寄存器写使能，高电平有效
    output reg reg_dst,      // 输出：写回寄存器选择 0=rt, 1=rd
    output reg alu_src,      // 输出：ALU第二个操作数选择 0=rt, 1=立即数
    output reg [3:0] aluc,   // 输出：ALU控制信号，直接送你之前的ALU
    output reg mem_write,    // 输出：数据存储器写使能，高电平有效
    output reg mem_to_reg,   // 输出：写回数据选择 0=ALU, 1=DM
    output reg branch,       // 输出：分支指令标志
    output reg branch_ne,    // 输出：bne标志，1=不相等分支(bne)，0=相等分支(beq)
    output reg shift,        // 输出：移位指令标志，1=使用移位量参与ALU运算
    output reg shift_var,    // 输出：变长移位标志，1=使用rs作为移位量
    output reg jump,         // 输出：J型跳转标志（j/jal）
    output reg jump_reg,     // 输出：寄存器跳转标志（jr）
    output reg link,         // 输出：链接指令标志（jal）
    output reg ext_sign      // 输出：立即数扩展方式 0=零扩展, 1=符号扩展
);

// 核心控制逻辑：纯组合逻辑，无时钟无复位
always @(*) begin
    // 先给所有控制信号赋默认值，防止出现锁存器
    reg_write   = 1'b0;
    reg_dst     = 1'b0;
    alu_src     = 1'b0;
    aluc        = 4'b0000;
    mem_write   = 1'b0;
    mem_to_reg  = 1'b0;
    branch      = 1'b0;
    branch_ne   = 1'b0;
    shift       = 1'b0;
    shift_var   = 1'b0;
    jump        = 1'b0;
    jump_reg    = 1'b0;
    link        = 1'b0;
    ext_sign    = 1'b1; // 默认符号扩展

    case(op)
        // R型指令：op=000000，具体功能看func
        6'b000000: begin
            case(func)
                // add: 有符号加法
                6'b100000: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0010;
                end
                // addu: 无符号加法
                6'b100001: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0000;
                end
                // sub: 有符号减法
                6'b100010: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0011;
                end
                // subu: 无符号减法
                6'b100011: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0001;
                end
                // and: 按位与
                6'b100100: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0100;
                end
                // or: 按位或
                6'b100101: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0101;
                end
                // xor: 按位异或
                6'b100110: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0110;
                end
                // nor: 按位或非
                6'b100111: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b0111;
                end
                // slt: 有符号小于比较
                6'b101010: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b1011;
                end
                // sltu: 无符号小于比较
                6'b101011: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    aluc      = 4'b1010;
                end
                // sll: 逻辑左移
                6'b000000: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    shift     = 1'b1;
                    aluc      = 4'b1110;
                end
                // srl: 逻辑右移
                6'b000010: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    shift     = 1'b1;
                    aluc      = 4'b1101;
                end
                // sra: 算术右移
                6'b000011: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    shift     = 1'b1;
                    shift_var = 1'b0;
                    aluc      = 4'b1100;
                end
                // sllv: 逻辑左移（由寄存器控制）
                6'b000100: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    shift     = 1'b1;
                    shift_var = 1'b1;
                    aluc      = 4'b1110;
                end
                // srlv: 逻辑右移（由寄存器控制）
                6'b000110: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    shift     = 1'b1;
                    shift_var = 1'b1;
                    aluc      = 4'b1101;
                end
                // srav: 算术右移（由寄存器控制）
                6'b000111: begin
                    reg_write = 1'b1;
                    reg_dst   = 1'b1;
                    shift     = 1'b1;
                    shift_var = 1'b1;
                    aluc      = 4'b1100;
                end
                // jr: 寄存器跳转
                6'b001000: begin
                    jump_reg = 1'b1;
                end
                default: begin
                    // 未定义的func，所有控制信号保持默认
                end
            endcase
        end

        // J型指令
        // j: 无条件跳转
        6'b000010: begin
            jump = 1'b1;
        end
        // jal: 跳转并链接
        6'b000011: begin
            jump      = 1'b1;
            reg_write = 1'b1;
            link      = 1'b1;
        end

        // I型指令
        // addi: 有符号加法立即数
        6'b001000: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b0010;
        end
        // addiu: 无符号加法立即数
        6'b001001: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b0000;
        end
        // andi: 按位与立即数（零扩展）
        6'b001100: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b0100;
            ext_sign  = 1'b0;
        end
        // ori: 按位或立即数（零扩展）
        6'b001101: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b0101;
            ext_sign  = 1'b0;
        end
        // xori: 按位异或立即数（零扩展）
        6'b001110: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b0110;
            ext_sign  = 1'b0;
        end
        // lui: 加载立即数到高位
        6'b001111: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b1000;
            ext_sign  = 1'b0; // LUI 使用零扩展立即数
        end
        // lw: 取字
        6'b100011: begin
            reg_write  = 1'b1;
            alu_src    = 1'b1;
            aluc       = 4'b0000;
            mem_to_reg = 1'b1;
        end
        // sw: 存字
        6'b101011: begin
            alu_src   = 1'b1;
            aluc      = 4'b0000;
            mem_write = 1'b1;
        end
        // beq: 相等则分支
        6'b000100: begin
            branch    = 1'b1;
            branch_ne = 1'b0;
            aluc      = 4'b0011;
        end
        // bne: 不相等则分支
        6'b000101: begin
            branch    = 1'b1;
            branch_ne = 1'b1;
            aluc      = 4'b0011;
        end
        // slti: 有符号小于立即数
        6'b001010: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b1011;
        end
        // sltiu: 无符号小于立即数
        6'b001011: begin
            reg_write = 1'b1;
            alu_src   = 1'b1;
            aluc      = 4'b1010;
        end

        default: begin
            // 未定义的op，所有控制信号保持默认
        end
    endcase
end

endmodule