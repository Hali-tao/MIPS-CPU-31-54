// 文件名：cu.v
// 功能：多周期MIPS CPU控制单元顶层
module cu(
    input              clk,
    input              rst,
    input      [31:0]  inst,           // 来自多周期数据通路内部的 IR 寄存器
    input              zero,           // 来自 ALU 的零标志位，用于分支指令判断
    input              neg,            // 来自rs[31]的符号位，用于bgez指令判断
    input              busy,           // 来自乘除法器的忙标志位（对应时间表中的 busy=0 才能跳转）
    input      [31:0]  cp0_status,     // 来自 CP0 的 Status 寄存器值，用于异常判断
    input              intr,           // 来自外部的中断请求信号

    // ==================== 传回给数据通路的控制信号 ====================
    output             PCin,           // PC寄存器写使能
    output             IRin,           // IR指令寄存器写使能
    output             reg_write,      // 通用寄存器堆写使能
    output             ext_sign,       // 立即数扩展: 1=符号扩展, 0=零扩展
    output     [1:0]   mem_size,       // 访存数据大小: 00=Word, 01=Byte, 10=Halfword
    output             mem_sign,       // 内存读符号扩展: 1=有符号, 0=无符号
    output             Zin,            // ALUout/Z寄存器写使能
    output     [3:0]   aluc,           // ALU控制码 [3:0]
    output             mem_read,       // 内存读使能
    output             mem_write,      // 内存写使能
    output             mfc0,           // 读CP0寄存器标志
    output             mtc0,           // 写CP0寄存器标志
    output             exception,      // 异常触发标志
    output     [4:0]   exc_cause,      // 异常原因码 (syscall=8, break=9, teq=13)
    output             eret,           // 异常返回指令标志
    output             hi_w,           // HI寄存器写使能
    output             lo_w,           // LO寄存器写使能
    output     [1:0]   md_op,          // 乘除法操作码: 00=mult, 01=multu, 10=div, 11=divu
    output             is_md_inst,     // 当前指令是否为乘除法指令
    output             md_t3,
    output             pc_update,      // PC更新标志，用于控制PC输出信号
    //output             zero_wena,      // 零寄存器写使能
    
    // 多周期所需的各种多路选择器(MUX)控制信号
    output     [1:0]   rf_waddr_sel,   // 写回寄存器地址选择 (00=$31, 01=rd, 10=rt)
    output     [1:0]   alu_src_A,      // ALU输入A选择: 00=shamt移位  01=rs, 10=pc
    output     [1:0]   alu_src_B,      // ALU输入B选择: 00=rt, 01=立即数扩展, 10=分支imm[15:0]||0^2, 11=4(用于PC+4)
    output             z_in_sel,       // 0=clz, 1=alu 
    output     [2:0]   rf_wdata_sel,   // 写回寄存器数据源选择 (000=cp0,001=load_dm,010=z,011=pc,100=hi,101=lo)
    output     [2:0]   pc_src,         // PC选择: 000=z, 001=跳转地址, 010=exc_addr, 011=寄存器跳转地址， 100=异常返回地址
    output             hi_src,         // HI寄存器写入源选择: 0=通用寄存器rs(mthi), 1=乘除法器
    output             lo_src          // LO寄存器写入源选择: 0=通用寄存器rs(mthi), 1=乘除法器
);

    // ====================================================
    //                       译码器
    // ====================================================
    wire inst_add,  inst_addu, inst_sub,  inst_subu, inst_and,  inst_or,  inst_xor,  inst_nor,  inst_slt,  inst_sltu;
    wire inst_sll,  inst_srl,  inst_sra,  inst_sllv, inst_srlv, inst_srav;
    wire inst_jr,   inst_jalr;
    wire inst_mult, inst_multu,inst_div,  inst_divu, inst_mfhi, inst_mflo, inst_mthi, inst_mtlo;
    wire inst_syscall, inst_break, inst_teq;
    wire inst_j,    inst_jal;
    wire inst_addi, inst_addiu,inst_andi, inst_ori,  inst_xori, inst_lui;
    wire inst_slti, inst_sltiu,inst_beq,  inst_bne,  inst_bgez;
    wire inst_lw,   inst_lb,   inst_lbu,  inst_lh,   inst_lhu;
    wire inst_sw,   inst_sb,   inst_sh;
    wire inst_mfc0, inst_mtc0, inst_eret;
    wire inst_clz;

    decoder u_decoder(
        .inst(inst),
        .inst_add(inst_add), .inst_addu(inst_addu), .inst_sub(inst_sub), .inst_subu(inst_subu),
        .inst_and(inst_and), .inst_or(inst_or), .inst_xor(inst_xor), .inst_nor(inst_nor),
        .inst_slt(inst_slt), .inst_sltu(inst_sltu), .inst_sll(inst_sll), .inst_srl(inst_srl),
        .inst_sra(inst_sra), .inst_sllv(inst_sllv), .inst_srlv(inst_srlv), .inst_srav(inst_srav),
        .inst_jr(inst_jr), .inst_jalr(inst_jalr), .inst_mult(inst_mult), .inst_multu(inst_multu),
        .inst_div(inst_div), .inst_divu(inst_divu), .inst_mfhi(inst_mfhi), .inst_mflo(inst_mflo),
        .inst_mthi(inst_mthi), .inst_mtlo(inst_mtlo), .inst_syscall(inst_syscall), .inst_break(inst_break),
        .inst_teq(inst_teq), .inst_j(inst_j), .inst_jal(inst_jal), .inst_addi(inst_addi),
        .inst_addiu(inst_addiu), .inst_andi(inst_andi), .inst_ori(inst_ori), .inst_xori(inst_xori),
        .inst_lui(inst_lui), .inst_slti(inst_slti), .inst_sltiu(inst_sltiu), .inst_beq(inst_beq),
        .inst_bne(inst_bne), .inst_bgez(inst_bgez), .inst_lw(inst_lw), .inst_lb(inst_lb),
        .inst_lbu(inst_lbu), .inst_lh(inst_lh), .inst_lhu(inst_lhu), .inst_sw(inst_sw),
        .inst_sb(inst_sb), .inst_sh(inst_sh), .inst_mfc0(inst_mfc0), .inst_mtc0(inst_mtc0),
        .inst_eret(inst_eret), .inst_clz(inst_clz)
    );

    // ====================================================
    //                    多周期状态机
    // ====================================================
    // 独热码状态定义，每个状态对应当前状态总线的一位
    parameter S_T1 = 5'b00001,
              S_T2 = 5'b00010,
              S_T3 = 5'b00100,
              S_T4 = 5'b01000,
              S_T5 = 5'b10000;

    reg [4:0] current_state, next_state;

    // 状态更新 (时序逻辑)
    always @(posedge clk or posedge rst) begin
        if (rst) current_state <= S_T1;
        else     current_state <= next_state;
    end

    wire ie_en         =  cp0_status[0];
    wire syscall_taken = ~cp0_status[8]  & ie_en;
    wire break_taken   = ~cp0_status[9]  & ie_en;
    wire teq_taken     = ~cp0_status[10] & ie_en;
    wire intr_taken    =  intr & ie_en;


    always @(*) begin
        case(current_state)
            S_T1: next_state = S_T2; // T1取指必进T2
            S_T2: begin
                if((inst_bgez && neg) || (inst_break && ~break_taken) || (inst_syscall && ~syscall_taken) || (inst_teq && ~teq_taken))begin
                    next_state = S_T1; // T2中异常指令直接回T1
                end else begin
                    next_state = S_T3; // 其余指令进T3
                end
            end
            S_T3: begin
                // 1. 三周期即可结束并跳转的指令
                if (inst_j || inst_jal || inst_jr || inst_jalr || 
                inst_mfhi || inst_mflo || inst_mthi || inst_mtlo || inst_mfc0 || inst_mtc0 ||
                inst_syscall || inst_break || inst_eret)
                    next_state = S_T1;
                else if ((inst_beq && !zero) ||
                         (inst_bne && zero) ||
                         (inst_teq && !zero)) begin
                            next_state = S_T1;
                         end
                // 2. 乘除法指令，如果计算未完成(busy=1)则维持在T3，完成后(busy=0)进T4结束
                else if (inst_div || inst_divu || inst_mult || inst_multu) begin
                    if (busy) next_state = S_T3;
                    else      next_state = S_T4;
                end
                // 3. 其余通用计算/分支/访存指令必进入T4
                else begin
                    next_state = S_T4;
                end
            end
            S_T4: begin
                if (inst_beq || inst_bne)
                    next_state = S_T5;
                else
                    next_state = S_T1;
            end
            S_T5: begin
                next_state = S_T1; // 五周期写回完毕，无条件回 T1
            end
            default: next_state = S_T1;
        endcase
    end

    wire t1 = current_state[0];
    wire t2 = current_state[1];
    wire t3 = current_state[2];
    wire t4 = current_state[3];
    wire t5 = current_state[4];

    // ====================================================
    //                      控制信号
    // ====================================================
    
    // 立即数计算写回
    wire is_calc_imm = inst_addi || inst_addiu || inst_andi || inst_ori || inst_xori || inst_lui || inst_slti || inst_sltiu;
    // 寄存器计算写回
    wire is_calc_r   = inst_add || inst_addu || inst_sub || inst_subu || inst_and || inst_or || inst_xor || inst_nor || inst_slt || inst_sltu || inst_sll || inst_srl || inst_sra || inst_sllv || inst_srlv || inst_srav;
    // 读主存写回
    wire is_load_mem = inst_lw || inst_lb || inst_lbu || inst_lh || inst_lhu;
    // 写主存
    wire is_safe_mem = inst_sw || inst_sb || inst_sh;
    wire is_sl = is_load_mem || is_safe_mem;
    // 乘除法运算
    wire is_md = inst_mult || inst_multu || inst_div || inst_divu;

    // PC写信号
    assign PCin = t2 || 
        (t3 && (inst_j || inst_jal || inst_jr || inst_jalr || inst_break || inst_syscall || inst_eret)) || 
        (t4 && (inst_bgez || inst_teq)) || 
        (t5 && (inst_beq || inst_bne));

    // IRin 取指
    assign IRin = t1;
    
    // reg_write (寄存器写使能)
    assign reg_write   = (t3 && (inst_jal || inst_jalr || inst_mfhi || inst_mflo || inst_mfc0)) || 
        (t4 && (is_calc_imm || is_calc_r || is_load_mem || inst_clz));

    // 立即数扩展符号位选择
    assign ext_sign = !(inst_andi || inst_ori || inst_xori);

    // 访存数据大小选择
    assign mem_size = (inst_lb || inst_lbu || inst_sb) ? 2'b01 :
                      (inst_lh || inst_lhu || inst_sh) ? 2'b10 : 2'b00;

    assign mem_sign = (inst_lb || inst_lh);

    // Zin
    assign Zin = t1 || 
        (t3 && (is_calc_imm || inst_clz || is_calc_r || is_sl || inst_bgez)) || 
        (t4 && (inst_beq || inst_bne));

    // aluc
    reg [3:0] aluc_reg;
    assign aluc = aluc_reg;
    always @(*) begin
        aluc_reg = 4'b0000; 
        if (t1) begin
            aluc_reg = 4'b0000; // ADDU (PC+4 通常用无符号加)
        end 
        else if (t4) begin
            if (inst_beq || inst_bne) aluc_reg = 4'b0010; // T4下分支指令计算用 ADD
        end 
        else if (t3) begin
            case (1'b1)
                // 4'b0000: ADDU
                inst_addu || inst_addiu || is_sl : aluc_reg = 4'b0000;
                
                // 4'b0010: ADD
                inst_add  || inst_addi  || inst_bgez: aluc_reg = 4'b0010;
                
                // 4'b0011: SUB
                inst_sub  || inst_beq   || inst_bne  || inst_teq : aluc_reg = 4'b0011;
                
                // 4'b0001: SUBU
                inst_subu : aluc_reg = 4'b0001;
                
                // 逻辑运算
                inst_and  || inst_andi  : aluc_reg = 4'b0100;
                inst_or   || inst_ori   : aluc_reg = 4'b0101;
                inst_xor  || inst_xori  : aluc_reg = 4'b0110;
                inst_nor                : aluc_reg = 4'b0111;
                
                // 比较与移位
                inst_slt  || inst_slti  : aluc_reg = 4'b1011;
                inst_sltu || inst_sltiu : aluc_reg = 4'b1010;
                inst_sll  || inst_sllv  : aluc_reg = 4'b1110;
                inst_srl  || inst_srlv  : aluc_reg = 4'b1101;
                inst_sra  || inst_srav  : aluc_reg = 4'b1100;
                inst_lui                : aluc_reg = 4'b1000;
                
                default: aluc_reg = 4'b0000;
            endcase
        end
    end

    // 内存读写
    assign mem_read      = t4 && (is_load_mem);
    assign mem_write     = t4 && (is_safe_mem);

    // --- 乘除法、CP0 ---
    assign mfc0       = t3 && inst_mfc0;
    assign mtc0       = t3 && inst_mtc0;
    assign exception  = (intr && intr_taken) || 
                        (inst_syscall && syscall_taken) || 
                        (inst_break && break_taken) || 
                        (inst_teq && teq_taken);

    assign exc_cause  = intr_taken ? 5'd0 : 
                        inst_syscall ? 5'd8 : 
                        inst_break ? 5'd9 : 
                        inst_teq ? 5'd13 : 5'd0;

    assign eret       = inst_eret;
    assign hi_w       = (t3 && inst_mthi) || (t4 && is_md);
    assign lo_w       = (t3 && inst_mtlo) || (t4 && is_md);
    assign md_op      = inst_mult  ? 2'b00 :
                        inst_multu ? 2'b01 :
                        inst_div   ? 2'b10 :
                        inst_divu  ? 2'b11 : 2'b00;
    // 乘除法操作码: 00=mult, 01=multu, 10=div, 11=divu
    assign is_md_inst = inst_mult || inst_multu || inst_div || inst_divu;
    assign md_t3 = t3;
    assign pc_update = t1;
    // zero
    // assign zero_wena = t3 && (inst_beq || inst_bne || inst_teq);

    // ====================================================
    //                        多路选择器
    // ====================================================
    // output     [1:0]   rf_waddr_sel,   // 写回寄存器地址选择 (00=$31, 01=rd, 10=rt)
    // output     [1:0]   alu_src_A,      // ALU输入A选择: 00=shamt移位  01=rs, 10=pc
    // output     [1:0]   alu_src_B,      // ALU输入B选择: 00=rt, 01=立即数扩展, 10=分支imm[15:0]||0^2, 11=4(用于PC+4)
    // output             z_in_sel,       // 0=clz, 1=alu 
    // output     [2:0]   rf_wdata_sel,   // 写回寄存器数据源选择 (000=cp0,001=load_dm,010=z,011=pc,100=hi,101=lo)
    // output     [2:0]   pc_src,         // PC选择: 000=z, 001=跳转地址, 010=exc_addr, 011=寄存器跳转地址， 100=异常返回地址
    // output             hi_src,         // HI寄存器写入源选择: 0=通用寄存器rs(mthi), 1=乘除法器
    // output             lo_src          // LO寄存器写入源选择: 0=通用寄存器rs(mthi), 1=乘除法器
    
    // 寄存器写回地址选择器
    assign rf_waddr_sel = (t3 && (inst_jal)) ? 2'b00 : // $31
        ((t3 && (inst_mfhi || inst_mflo || inst_jalr)) || (t4 && (is_calc_r || inst_clz))) ? 2'b01 : // rd
        ((t3 && inst_mfc0) || (t4 && (is_calc_imm || is_load_mem))) ? 2'b10 : 2'b00; // rt

    // alu_a输入选择
    assign alu_src_A = (t3 && (inst_sll || inst_srl || inst_sra)) ? 2'b00 : // shamt
        (t3 && (is_calc_r || is_calc_imm || is_sl || inst_beq || inst_bne || inst_teq)) ? 2'b01 : // rs
        t1 || (t3 && inst_bgez) || (t4 && (inst_beq || inst_bne)) ? 2'b10 : // pc
        2'b01; // default
    
    // alu_b输入选择
    assign alu_src_B = (t3 && (is_calc_r || inst_beq || inst_bne || inst_teq)) ? 2'b00 : // rt
        (t3 && (is_calc_imm || is_sl)) ? 2'b01 : // imm
        (t3 && inst_bgez) || (t4 && (inst_beq || inst_bne)) ? 2'b10 : // branch
        2'b11; // 4

    // z_in_sel
    assign z_in_sel = (t3 && inst_clz) ? 1'b0 : 1'b1;

    // rf_wdata_sel
    assign rf_wdata_sel = (t3 && (inst_jal || inst_jalr)) ? 3'b011 : // pc
        (t4 && is_load_mem) ? 3'b001 : // load_dm
        (t4 && (is_calc_r || is_calc_imm || inst_clz)) ? 3'b010 : // z
        (t3 && inst_mfc0) ? 3'b000 : // cp0
        (t3 && inst_mfhi) ? 3'b100 : // hi
        (t3 && inst_mflo) ? 3'b101 : // lo
        3'b010; // default

    // pc_src
    assign pc_src = (t2 || (t4 && inst_bgez) || (t5 && (inst_beq || inst_bne))) ? 3'b000 : // z
        (t3 && (inst_j || inst_jal)) ? 3'b001 : // jump
        (t3 && (inst_jr || inst_jalr)) ? 3'b011 : // reg jump
        ((t3 && (inst_syscall || inst_break)) || (t4 && inst_teq)) ? 3'b010 : // exc_addr
        (t3 && inst_eret) ? 3'b100 : // epc_out
        3'b000; // default
    
    // hi_src
    assign hi_src = (t3 && inst_mthi) ? 1'b0 : 1'b1; // md

    // lo_src
    assign lo_src = (t3 && inst_mtlo) ? 1'b0 : 1'b1; // md

endmodule
