// 文件名：cpu.v
// 功能：单周期MIPS CPU顶层模块
module cpu(
    input clk,
    input ena,
    input rst,
    input [31:0] inst,
    input [31:0] dm_rdata,

    output dm_ena,
    output dm_we,
    output dm_re,
    output [31:0] dm_addr,
    output [31:0] dm_wdata,

    output [31:0] pc_out


    // // 调试输出信号
    // output [31:0] debug_pc,    // 调试：当前PC值
    // output [31:0] debug_inst,  // 调试：当前指令
    // output [31:0] debug_rdata1,// 调试：寄存器读数据1
    // output [31:0] debug_rdata2,// 调试：寄存器读数据2
    // output [31:0] debug_alu_r, // 调试：ALU运算结果
    // output [31:0] debug_wdata  // 调试：寄存器写回数据
);

    // pc
    wire [31:0] pc_next;       // PC输入：下一条指令地址
    wire [31:0] pc_plus_4;     // PC+4：正常执行的下一条地址

    // 寄存器堆相关
    wire [4:0]  raddr1;        // RF读地址1：rs
    wire [4:0]  raddr2;        // RF读地址2：rt
    wire [4:0]  waddr;         // RF写地址：选择后的rt/rd/$31
    wire [31:0] rdata1;        // RF读数据1
    wire [31:0] rdata2;        // RF读数据2
    wire [31:0] wdata;         // RF写数据：选择后的ALU结果/DM数据/PC+4

    // 符号扩展相关
    wire [15:0] imm_16;        // 16位立即数：inst[15:0]
    wire [31:0] imm_32;        // 32位扩展后立即数

    // ALU相关
    wire [31:0] alu_a;         // ALU操作数A：正常是rs，移位时是shamt
    wire [31:0] alu_b;         // ALU操作数B：选择后的rdata2/imm_32
    wire [31:0] alu_r;         // ALU运算结果
    wire        zero;          // ALU零标志位

    // 控制单元相关
    wire        reg_write;      // 寄存器写使能
    wire        reg_dst;        // 写地址选择
    wire        alu_src;        // ALU操作数B选择
    wire [3:0]  aluc;           // ALU控制信号
    wire        mem_write;      // 存储器写使能
    wire        mem_to_reg;     // 写回数据选择
    wire        branch;         // 分支指令标志
    wire        branch_ne;      // bne标志，1=不相等分支(bne)
    wire        shift;          // 移位指令标志，使用移位量参与ALU运算
    wire        shift_var;      // 变长移位标志，1=使用rs作为移位量
    wire        jump;           // J型跳转标志
    wire        jump_reg;       // 寄存器跳转标志
    wire        link;           // 链接指令标志
    wire        ext_sign;       // 立即数扩展方式

    // PC选择逻辑相关
    wire [31:0] branch_target;  // 分支目标地址
    wire [31:0] jump_target;    // J型跳转目标地址
    wire [31:0] jr_target;      // JR跳转目标地址
    wire        branch_taken;    // 分支是否发生

    // ==================== 指令字段拆分 ====================
    assign raddr1 = inst[25:21];   // rs
    assign raddr2 = inst[20:16];   // rt
    assign imm_16 = inst[15:0];    // 16位立即数

    // ==================== 1. PC模块实例化 ====================
    pc u_pc(
        .clk(clk),
        .rst(rst),
        .npc(pc_next),
        .pc(pc_out)
    );

    // ==================== 2. 寄存器堆RF实例化 ====================
    regfile cpu_ref(
        .clk(clk),
        .ena(ena),
        .rst(rst),
        .wena(reg_write),
        .raddr1(raddr1),
        .raddr2(raddr2),
        .waddr(waddr),
        .wdata(wdata),
        .rdata1(rdata1),
        .rdata2(rdata2)
    );

    // ==================== 4. 符号扩展单元EXT实例化 ====================
    ext u_ext(
        .imm_16(imm_16),
        .ext_op(ext_sign),
        .imm_32(imm_32)
    );

    // ==================== 5. ALU模块实例化 ====================
    alu u_alu(
        .a(alu_a),
        .b(alu_b),
        .aluc(aluc),
        .r(alu_r),
        .zero(zero),
        // 以下标志位单周期CPU暂时不用，可悬空
        .carry(),
        .negative(),
        .overflow()
    );

    // ==================== 6. DM 外部总线输出 ====================
    assign dm_ena   = ena & (mem_write | mem_to_reg);
    assign dm_we    = ena & mem_write;
    assign dm_re    = ena & mem_to_reg;
    assign dm_addr  = alu_r;
    assign dm_wdata = rdata2;

    // ==================== 7. 控制单元CU实例化 ====================
    cu u_cu(
        .op(inst[31:26]),
        .func(inst[5:0]),
        .reg_write(reg_write),
        .reg_dst(reg_dst),
        .alu_src(alu_src),
        .aluc(aluc),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .branch(branch),
        .branch_ne(branch_ne),
        .shift(shift),
        .shift_var(shift_var),
        .jump(jump),
        .jump_reg(jump_reg),
        .link(link),
        .ext_sign(ext_sign)
    );

    // ==================== 数据选择器逻辑 ====================
    // 选择器1：RF写地址选择
    // link=1（jal）：写$31（5'b11111）
    // reg_dst=1（R型）：写rd（inst[15:11]）
    // 否则（I型）：写rt（inst[20:16]）
    assign waddr = link ? 5'b11111 : (reg_dst ? inst[15:11] : inst[20:16]);

    // 选择器2：ALU操作数B选择
    // alu_src=1：选扩展后的立即数imm_32
    // 否则：选寄存器读数据2 rdata2
    assign alu_b = alu_src ? imm_32 : rdata2;

    // 选择器3：ALU操作数A选择
    // shift=1：移位指令，使用移位量参与ALU运算
    // shift_var=1：使用rs的低5位作为变长移位量
    // 否则：使用指令中的shamt inst[10:6]
    assign alu_a = shift ? (shift_var ? {27'b0, rdata1[4:0]} : {27'b0, inst[10:6]}) : rdata1;

    // 选择器4：RF写数据选择
    // link=1（jal）：写PC+4（返回地址）
    // mem_to_reg=1（lw）：写DM读数据dm_rdata
    // 否则：写ALU运算结果alu_r
    assign wdata = link ? pc_plus_4 : (mem_to_reg ? dm_rdata : alu_r);

    // ==================== PC更新逻辑 ====================
    // 1. PC+4：正常执行的下一条地址
    assign pc_plus_4 = pc_out + 32'd4;

    // 2. 分支目标地址：PC+4 + (imm_32左移2位)
    assign branch_target = pc_plus_4 + {imm_32[29:0], 2'b00};

    // 3. J型跳转目标地址：{PC+4[31:28], inst[25:0], 2'b00}
    assign jump_target = {pc_plus_4[31:28], inst[25:0], 2'b00};

    // 4. JR跳转目标地址：寄存器rs的值（rdata1）
    assign jr_target = rdata1;

    // 5. 分支是否发生：beq 时 zero=1，bne 时 zero=0
    // branch_ne=0 表示 beq；branch_ne=1 表示 bne
    assign branch_taken = branch & (zero ^ branch_ne);

    // 6. 最终PC选择
    // jump_reg=1（jr）：选jr_target
    // jump=1（j/jal）：选jump_target
    // branch_taken=1（beq/bne）：选branch_target
    // 否则：选pc_plus_4
    assign pc_next = jump_reg ? jr_target : 
                     (jump ? jump_target : 
                     (branch_taken ? branch_target : pc_plus_4));

endmodule