// 文件名：decoder.v
// 功能：纯组合逻辑，将输入的32位指令机器码平铺译码出所有54条指令的单线独热码(wire)
module decoder(
    input  [31:0] inst,
    output        inst_add,      
    output        inst_addu,     
    output        inst_sub,
    output        inst_subu,     
    output        inst_and,      
    output        inst_or,
    output        inst_xor,      
    output        inst_nor,      
    output        inst_slt,
    output        inst_sltu,
    output        inst_sll,      
    output        inst_srl,      
    output        inst_sra,
    output        inst_sllv,     
    output        inst_srlv,     
    output        inst_srav,
    output        inst_jr,       
    output        inst_jalr,
    output        inst_mult,     
    output        inst_multu,    
    output        inst_div,
    output        inst_divu,     
    output        inst_mfhi,     
    output        inst_mflo,
    output        inst_mthi,     
    output        inst_mtlo,
    output        inst_syscall,  
    output        inst_break,    
    output        inst_teq,
    output        inst_j,        
    output        inst_jal,
    output        inst_addi,     
    output        inst_addiu,    
    output        inst_andi,
    output        inst_ori,      
    output        inst_xori,     
    output        inst_lui,
    output        inst_slti,     
    output        inst_sltiu,    
    output        inst_beq,
    output        inst_bne,      
    output        inst_bgez,
    output        inst_lw,
    output        inst_lb,       
    output        inst_lbu,
    output        inst_lh,       
    output        inst_lhu,
    output        inst_sw,       
    output        inst_sb,       
    output        inst_sh,
    output        inst_mfc0,     
    output        inst_mtc0,     
    output        inst_eret,
    output        inst_clz
);

    // ==================== 1. 内部核心字段切片提取 ====================
    wire [5:0] op   = inst[31:26];  // 指令操作码
    wire [4:0] rs   = inst[25:21];  // 寄存器rs字段
    wire [4:0] rt   = inst[20:16];  // 寄存器rt字段
    wire [5:0] func = inst[5:0];    // R型功能码

    // ==================== 2. 大类前置译码基准线 ====================
    wire op_r       = (op == 6'b000000); // 标准R型指令
    wire op_cp0     = (op == 6'b010000); // CP0协处理器大类
    wire op_regimm  = (op == 6'b000001); // REGIMM分支大类(含bgez)

    // ==================== 3. 54条指令独热码精确平铺 ====================
    
    // 1. R型 算术逻辑指令
    assign inst_add     = op_r && (func == 6'b100000);
    assign inst_addu    = op_r && (func == 6'b100001);
    assign inst_sub     = op_r && (func == 6'b100010);
    assign inst_subu    = op_r && (func == 6'b100011);
    assign inst_and     = op_r && (func == 6'b100100);
    assign inst_or      = op_r && (func == 6'b100101);
    assign inst_xor     = op_r && (func == 6'b100110);
    assign inst_nor     = op_r && (func == 6'b100111);
    assign inst_slt     = op_r && (func == 6'b101010);
    assign inst_sltu    = op_r && (func == 6'b101011);

    // 2. R型 移位指令
    assign inst_sll     = op_r && (func == 6'b000000);
    assign inst_srl     = op_r && (func == 6'b000010);
    assign inst_sra     = op_r && (func == 6'b000011);
    assign inst_sllv    = op_r && (func == 6'b000100);
    assign inst_srlv    = op_r && (func == 6'b000110);
    assign inst_srav    = op_r && (func == 6'b000111);

    // 3. R型 跳转指令
    assign inst_jr      = op_r && (func == 6'b001000);
    assign inst_jalr    = op_r && (func == 6'b001001);

    // 4. R型 乘除法与HI/LO寄存器指令
    assign inst_mult    = op_r && (func == 6'b011000);
    assign inst_multu   = op_r && (func == 6'b011001);
    assign inst_div     = op_r && (func == 6'b011010);
    assign inst_divu    = op_r && (func == 6'b011011);
    assign inst_mfhi    = op_r && (func == 6'b010000);
    assign inst_mflo    = op_r && (func == 6'b010010);
    assign inst_mthi    = op_r && (func == 6'b010001);
    assign inst_mtlo    = op_r && (func == 6'b010011);

    // 5. R型 异常指令 
    assign inst_syscall = op_r && (func == 6'b001100);
    assign inst_break   = op_r && (func == 6'b001101);
    assign inst_teq     = op_r && (func == 6'b110100);

    // 6. J型 跳转指令 
    assign inst_j       = (op == 6'b000010);
    assign inst_jal     = (op == 6'b000011);

    // 7. I型 算术逻辑指令 
    assign inst_addi    = (op == 6'b001000);
    assign inst_addiu   = (op == 6'b001001);
    assign inst_andi    = (op == 6'b001100);
    assign inst_ori     = (op == 6'b001101);
    assign inst_xori    = (op == 6'b001110);
    assign inst_lui     = (op == 6'b001111);

    // 8. I型 比较与分支指令 
    assign inst_slti    = (op == 6'b001010);
    assign inst_sltiu   = (op == 6'b001011);
    assign inst_beq     = (op == 6'b000100);
    assign inst_bne     = (op == 6'b000101);
    assign inst_bgez    = op_regimm && (rt == 5'b00001);

    // 9. I型 内存读取指令 
    assign inst_lw      = (op == 6'b100011);
    assign inst_lb      = (op == 6'b100000);
    assign inst_lbu     = (op == 6'b100100);
    assign inst_lh      = (op == 6'b100001);
    assign inst_lhu     = (op == 6'b100101);

    // 10. I型 内存写入指令 
    assign inst_sw      = (op == 6'b101011);
    assign inst_sb      = (op == 6'b101000);
    assign inst_sh      = (op == 6'b101001);

    // 11. CP0 相关指令 (结合op大类与rs字段或func译码) 
    assign inst_mfc0    = op_cp0 && (rs == 5'b00000);
    assign inst_mtc0    = op_cp0 && (rs == 5'b00100);
    assign inst_eret    = op_cp0 && (rs == 5'b10000) && (func == 6'b011000);

    // 12. CLZ 前导零指令 
    assign inst_clz     = (op == 6'b011100) && (func == 6'b100000);

endmodule
