// 文件名：cu.v
// 功能：单周期MIPS CPU控制单元（全面支持54条扩展指令与CP0异常处理）
module cu(
    input  [5:0] op,         // 指令操作码 inst[31:26]
    input  [4:0] rs,         // 寄存器rs字段 inst[25:21]
    input  [4:0] rt,         // 寄存器rt字段 inst[20:16]，用于bgez等区分
    input  [5:0] func,       // R型功能码 inst[5:0]
    
    // 基本数据通路控制
    output reg reg_write,    // 寄存器写使能
    output reg reg_dst,      // 写回目的选择: 0=rt, 1=rd
    output reg alu_src,      // ALU源B选择: 0=rt, 1=立即数
    output reg [3:0] aluc,   // ALU控制信号
    
    // 核心优化：通用寄存器写回数据选择总线
    // 000=ALU, 001=DM, 010=PC+4(jal/jalr), 011=CP0, 100=HI, 101=LO, 110=CLZ
    output reg [2:0] rf_wdata_sel, 
    
    // 跳转与分支控制
    output reg branch,       // 基础分支使能
    output reg branch_ne,    // 1=bne
    output reg inst_bgez,    // 1=bgez特判
    output reg jump,         // J型跳转(j, jal)
    output reg jump_reg,     // 寄存器跳转(jr, jalr)
    output reg link,         // 链接标志(jal)，强制写回$31
    
    // 移位与立即数控制
    output reg shift,        // 移位指令使能
    output reg shift_var,    // 变长移位(由rs控制)
    output reg ext_sign,     // 立即数扩展: 1=符号扩展, 0=零扩展
    
    // 访存精细化控制
    output reg mem_write,    // 内存写使能
    output reg [1:0] mem_size, // 00=Word, 01=Byte, 10=Halfword
    output reg mem_sign,     // 1=内存读符号扩展, 0=零扩展
    
    // 乘除法与HI/LO控制
    output reg hi_write,     // HI寄存器写使能
    output reg lo_write,     // LO寄存器写使能
    output reg whilo_src,    // 写入源: 0=乘除法器, 1=通用寄存器rs(mthi/mtlo)
    output reg [1:0] md_op,  // 00=mult, 01=multu, 10=div, 11=divu
    
    // CP0与异常控制
    output reg mtc0,         // 写CP0标志
    output reg inst_syscall, // syscall标志
    output reg inst_break,   // break标志
    output reg inst_teq,     // teq自陷标志
    output reg inst_eret     // eret返回标志
);

always @(*) begin
    // 1. 默认值初始化，防止Latch产生
    reg_write = 0; reg_dst = 0; alu_src = 0; aluc = 4'b0000;
    rf_wdata_sel = 3'b000; 
    branch = 0; branch_ne = 0; inst_bgez = 0; jump = 0; jump_reg = 0; link = 0;
    shift = 0; shift_var = 0; ext_sign = 1;
    mem_write = 0; mem_size = 2'b00; mem_sign = 0;
    hi_write = 0; lo_write = 0; whilo_src = 0; md_op = 2'b00;
    mtc0 = 0; inst_syscall = 0; inst_break = 0; inst_teq = 0; inst_eret = 0;

    // 2. 指令译码
    case(op)
        // R型指令
        6'b000000: begin
            case(func)
                // 算术逻辑
                6'b100000: begin reg_write=1; reg_dst=1; aluc=4'b0010; end // add
                6'b100001: begin reg_write=1; reg_dst=1; aluc=4'b0000; end // addu
                6'b100010: begin reg_write=1; reg_dst=1; aluc=4'b0011; end // sub
                6'b100011: begin reg_write=1; reg_dst=1; aluc=4'b0001; end // subu
                6'b100100: begin reg_write=1; reg_dst=1; aluc=4'b0100; end // and
                6'b100101: begin reg_write=1; reg_dst=1; aluc=4'b0101; end // or
                6'b100110: begin reg_write=1; reg_dst=1; aluc=4'b0110; end // xor
                6'b100111: begin reg_write=1; reg_dst=1; aluc=4'b0111; end // nor
                6'b101010: begin reg_write=1; reg_dst=1; aluc=4'b1011; end // slt
                6'b101011: begin reg_write=1; reg_dst=1; aluc=4'b1010; end // sltu
                
                // 移位
                6'b000000: begin reg_write=1; reg_dst=1; shift=1; aluc=4'b1110; end // sll
                6'b000010: begin reg_write=1; reg_dst=1; shift=1; aluc=4'b1101; end // srl
                6'b000011: begin reg_write=1; reg_dst=1; shift=1; shift_var=0; aluc=4'b1100; end // sra
                6'b000100: begin reg_write=1; reg_dst=1; shift=1; shift_var=1; aluc=4'b1110; end // sllv
                6'b000110: begin reg_write=1; reg_dst=1; shift=1; shift_var=1; aluc=4'b1101; end // srlv
                6'b000111: begin reg_write=1; reg_dst=1; shift=1; shift_var=1; aluc=4'b1100; end // srav
                
                // 跳转
                6'b001000: begin jump_reg=1; end // jr
                6'b001001: begin jump_reg=1; reg_write=1; reg_dst=1; rf_wdata_sel=3'b010; end // jalr (写入rd)
                
                // 乘除法与HI/LO
                6'b011000: begin hi_write=1; lo_write=1; whilo_src=0; md_op=2'b00; end // mult
                6'b011001: begin hi_write=1; lo_write=1; whilo_src=0; md_op=2'b01; end // multu
                6'b011010: begin hi_write=1; lo_write=1; whilo_src=0; md_op=2'b10; end // div
                6'b011011: begin hi_write=1; lo_write=1; whilo_src=0; md_op=2'b11; end // divu
                6'b010000: begin reg_write=1; reg_dst=1; rf_wdata_sel=3'b100; end // mfhi
                6'b010010: begin reg_write=1; reg_dst=1; rf_wdata_sel=3'b101; end // mflo
                6'b010001: begin hi_write=1; whilo_src=1; end // mthi
                6'b010011: begin lo_write=1; whilo_src=1; end // mtlo
                
                // 异常
                6'b001100: begin inst_syscall=1; end // syscall
                6'b001101: begin inst_break=1; end // break
                6'b110100: begin inst_teq=1; aluc=4'b0011; end // teq
                default: ;
            endcase
        end

        // J型指令
        6'b000010: begin jump=1; end // j
        6'b000011: begin jump=1; reg_write=1; link=1; rf_wdata_sel=3'b010; end // jal

        // I型指令
        6'b001000: begin reg_write=1; alu_src=1; aluc=4'b0010; end // addi
        6'b001001: begin reg_write=1; alu_src=1; aluc=4'b0000; end // addiu
        6'b001100: begin reg_write=1; alu_src=1; aluc=4'b0100; ext_sign=0; end // andi
        6'b001101: begin reg_write=1; alu_src=1; aluc=4'b0101; ext_sign=0; end // ori
        6'b001110: begin reg_write=1; alu_src=1; aluc=4'b0110; ext_sign=0; end // xori
        6'b001111: begin reg_write=1; alu_src=1; aluc=4'b1000; end // lui
        
        // 比较与分支
        6'b001010: begin reg_write=1; alu_src=1; aluc=4'b1011; end // slti
        6'b001011: begin reg_write=1; alu_src=1; aluc=4'b1010; end // sltiu
        6'b000100: begin branch=1; branch_ne=0; aluc=4'b0011; end // beq
        6'b000101: begin branch=1; branch_ne=1; aluc=4'b0011; end // bne
        6'b000001: begin if (rt == 5'b00001) begin branch=1; inst_bgez=1; ext_sign=1; end end // bgez

        // 内存读取 (统一设置 rf_wdata_sel=001)
        6'b100011: begin reg_write=1; alu_src=1; aluc=4'b0000; rf_wdata_sel=3'b001; mem_size=2'b00; end // lw
        6'b100000: begin reg_write=1; alu_src=1; aluc=4'b0000; rf_wdata_sel=3'b001; mem_size=2'b01; mem_sign=1; end // lb
        6'b100100: begin reg_write=1; alu_src=1; aluc=4'b0000; rf_wdata_sel=3'b001; mem_size=2'b01; mem_sign=0; end // lbu
        6'b100001: begin reg_write=1; alu_src=1; aluc=4'b0000; rf_wdata_sel=3'b001; mem_size=2'b10; mem_sign=1; end // lh
        6'b100101: begin reg_write=1; alu_src=1; aluc=4'b0000; rf_wdata_sel=3'b001; mem_size=2'b10; mem_sign=0; end // lhu

        // 内存写入
        6'b101011: begin alu_src=1; aluc=4'b0000; mem_write=1; mem_size=2'b00; end // sw
        6'b101000: begin alu_src=1; aluc=4'b0000; mem_write=1; mem_size=2'b01; end // sb
        6'b101001: begin alu_src=1; aluc=4'b0000; mem_write=1; mem_size=2'b10; end // sh

        // CP0 相关
        6'b010000: begin
            case(rs)
                5'b00000: begin reg_write=1; reg_dst=0; rf_wdata_sel=3'b011; end // mfc0 (写回rt)
                5'b00100: begin mtc0=1; end // mtc0
                5'b10000: begin if (func == 6'b011000) inst_eret=1; end // eret
                default: ;
            endcase
        end

        // CLZ 前导零
        6'b011100: begin
            if (func == 6'b100000) begin
                reg_write=1; reg_dst=1; rf_wdata_sel=3'b110; 
            end
        end

        default: ;
    endcase
end
endmodule