// 文件名：cpu.v
// 功能：单周期MIPS CPU顶层模块（全面集成54条指令、精细化访存及CP0中断处理）
module cpu(
    input clk,
    input ena,
    input rst,
    input [31:0] inst,
    input [31:0] dm_rdata,     // 从外挂DMEM读回的全字数据 (32位)
    input intr,                // 外部硬件中断请求

    output dm_ena,
    output reg [3:0] dm_we,    // 4位字节写使能 (供外挂BRAM使用)
    output dm_re,
    output [31:0] dm_addr,     // 内存地址 (需由外部模块截取 >> 2)
    output reg [31:0] dm_wdata,// 处理后的内存写入数据

    output [31:0] pc_out
);

    // ==================== 信号定义 ====================
    wire [31:0] pc_next, pc_plus_4, cp0_epc;
    wire [4:0]  rs = inst[25:21], rt = inst[20:16], rd = inst[15:11];
    wire [4:0]  shamt = inst[10:6];
    wire [15:0] imm_16 = inst[15:0];
    
    wire [31:0] imm_32, alu_a, alu_b, alu_r, rdata1, rdata2;
    wire [4:0]  waddr;
    wire [31:0] wdata;
    wire        zero;

    // CU 输出控制信号
    wire reg_write, reg_dst, alu_src, mem_write;
    wire [3:0] aluc;
    wire [2:0] rf_wdata_sel;
    wire branch, branch_ne, inst_bgez, jump, jump_reg, link, shift, shift_var, ext_sign;
    wire [1:0] mem_size; wire mem_sign;
    wire hi_write, lo_write, whilo_src; wire [1:0] md_op;
    wire mtc0, inst_syscall, inst_break, inst_teq, inst_eret;

    // 独立子模块输出信号
    wire [31:0] md_hi, md_lo, hi_out, lo_out, clz_out, cp0_rdata, cp0_status, cp0_exc_addr;
    wire        cp0_timer_int;
    reg  [31:0] final_dm_rdata; // 访存处理后的读数据

    // ==================== 1. CU 模块实例化 ====================
    cu u_cu(
        .op(inst[31:26]), .rs(rs), .rt(rt), .func(inst[5:0]),
        .reg_write(reg_write), .reg_dst(reg_dst), .alu_src(alu_src), .aluc(aluc),
        .rf_wdata_sel(rf_wdata_sel), .branch(branch), .branch_ne(branch_ne),
        .inst_bgez(inst_bgez), .jump(jump), .jump_reg(jump_reg), .link(link),
        .shift(shift), .shift_var(shift_var), .ext_sign(ext_sign),
        .mem_write(mem_write), .mem_size(mem_size), .mem_sign(mem_sign),
        .hi_write(hi_write), .lo_write(lo_write), .whilo_src(whilo_src), .md_op(md_op),
        .mtc0(mtc0), .inst_syscall(inst_syscall), .inst_break(inst_break), 
        .inst_teq(inst_teq), .inst_eret(inst_eret)
    );

    // ==================== 2. CP0 与 异常判定 ====================
    wire syscall_taken = inst_syscall & ~cp0_status[8];
    wire break_taken   = inst_break   & ~cp0_status[9];
    wire teq_taken     = inst_teq     & (rdata1 == rdata2) & ~cp0_status[10];
    wire intr_taken    = intr & cp0_status[0];
    
    wire exception = intr_taken | syscall_taken | break_taken | teq_taken;
    wire [4:0] exc_cause = intr_taken ? 5'd0 : syscall_taken ? 5'd8 : break_taken ? 5'd9 : teq_taken ? 5'd13 : 5'd0;

    CP0 u_cp0(
        .clk(clk), .rst(rst),
        .mfc0(rf_wdata_sel == 3'b011), .mtc0(mtc0), // 当 RF 写源为 011 时，说明是 mfc0
        .pc(pc_out), .Rd(rd), .wdata(rdata2),
        .exception(exception), .eret(inst_eret), .cause(exc_cause), .intr(intr),
        .rdata(cp0_rdata), .status(cp0_status), .timer_int(cp0_timer_int), .exc_addr(cp0_exc_addr), .epc_out(cp0_epc)
    );

    // ==================== 3. 基础 Datapath (PC / EXT / RegFile) ====================
    pc u_pc(.clk(clk), .rst(rst), .npc(pc_next), .pc(pc_out));
    
    ext u_ext(.imm_16(imm_16), .ext_op(ext_sign), .imm_32(imm_32));
    
    assign waddr = link ? 5'd31 : (reg_dst ? rd : rt);
    regfile cpu_ref(
        .clk(clk), .ena(ena), .rst(rst),
        .wena(reg_write & ~exception), // 异常时屏蔽写入
        .raddr1(rs), .raddr2(rt), .waddr(waddr), .wdata(wdata),
        .rdata1(rdata1), .rdata2(rdata2)
    );

    // ==================== 4. 运算部件 (ALU / CLZ / MULT_DIV / HILO) ====================
    assign alu_a = shift ? (shift_var ? {27'b0, rdata1[4:0]} : {27'b0, shamt}) : rdata1;
    assign alu_b = alu_src ? imm_32 : rdata2;
    alu u_alu(.a(alu_a), .b(alu_b), .aluc(aluc), .r(alu_r), .zero(zero), .carry(), .negative(), .overflow());

    clz u_clz(.in(rdata1), .out(clz_out)); 

    mult_div u_md(.a(rdata1), .b(rdata2), .mult_div_op(md_op), .hi_out(md_hi), .lo_out(md_lo));
    
    hilo_reg u_hilo(
        .clk(clk), .rst(rst), .hi_we(hi_write & ~exception), .lo_we(lo_write & ~exception),
        .hi_in(whilo_src ? rdata1 : md_hi), .lo_in(whilo_src ? rdata1 : md_lo),
        .hi_out(hi_out), .lo_out(lo_out)
    );

    // ==================== 5. RF数据写回总线 MUX ====================
    assign wdata = (rf_wdata_sel == 3'b000) ? alu_r :
                   (rf_wdata_sel == 3'b001) ? final_dm_rdata :
                   (rf_wdata_sel == 3'b010) ? (pc_out + 32'd4) : // jal / jalr
                   (rf_wdata_sel == 3'b011) ? cp0_rdata :
                   (rf_wdata_sel == 3'b100) ? hi_out :
                   (rf_wdata_sel == 3'b101) ? lo_out :
                   (rf_wdata_sel == 3'b110) ? clz_out : alu_r;

    // ==================== 6. PC 跳转与更新逻辑 ====================
    assign pc_plus_4 = pc_out + 32'd4;
    wire rs_gez = ~rdata1[31];
    wire branch_taken = branch & (inst_bgez ? rs_gez : (zero ^ branch_ne));
    
    wire [31:0] branch_target = pc_plus_4 + {imm_32[29:0], 2'b00};
    wire [31:0] jump_target   = {pc_plus_4[31:28], inst[25:0], 2'b00};
    wire [31:0] jr_target     = rdata1;

    assign pc_next = exception ? cp0_exc_addr :
                     inst_eret ? cp0_epc :
                     jump_reg  ? jr_target :
                     jump      ? jump_target :
                     branch_taken ? branch_target : pc_plus_4;

    // ==================== 7. 精细化访存控制 (Byte Enable & Extraction) ====================
    wire is_mem_read = (rf_wdata_sel == 3'b001);
    assign dm_ena  = ena & (mem_write | is_mem_read) & ~exception;
    assign dm_re   = ena & is_mem_read & ~exception;
    assign dm_addr = alu_r;
    
    // 写入控制 (sb, sh, sw)
    wire dm_we_base = ena & mem_write & ~exception;
    always @(*) begin
        dm_we = 4'b0000;
        dm_wdata = rdata2;
        if (dm_we_base) begin
            case(mem_size)
                2'b00: begin dm_we = 4'b1111; dm_wdata = rdata2; end // sw
                2'b10: begin // sh
                    if (alu_r[1] == 1'b0) begin dm_we = 4'b0011; dm_wdata = {16'b0, rdata2[15:0]}; end
                    else                  begin dm_we = 4'b1100; dm_wdata = {rdata2[15:0], 16'b0}; end
                end
                2'b01: begin // sb
                    case(alu_r[1:0])
                        2'b00: begin dm_we = 4'b0001; dm_wdata = {24'b0, rdata2[7:0]}; end
                        2'b01: begin dm_we = 4'b0010; dm_wdata = {16'b0, rdata2[7:0], 8'b0}; end
                        2'b10: begin dm_we = 4'b0100; dm_wdata = {8'b0, rdata2[7:0], 16'b0}; end
                        2'b11: begin dm_we = 4'b1000; dm_wdata = {rdata2[7:0], 24'b0}; end
                    endcase
                end
                default: ;
            endcase
        end
    end

    // 读出控制 (lb, lbu, lh, lhu, lw)
    always @(*) begin
        final_dm_rdata = dm_rdata; // 默认 lw
        case(mem_size)
            2'b01: begin // lb / lbu
                case(alu_r[1:0])
                    2'b00: final_dm_rdata = mem_sign ? {{24{dm_rdata[7]}},  dm_rdata[7:0]}   : {24'b0, dm_rdata[7:0]};
                    2'b01: final_dm_rdata = mem_sign ? {{24{dm_rdata[15]}}, dm_rdata[15:8]}  : {24'b0, dm_rdata[15:8]};
                    2'b10: final_dm_rdata = mem_sign ? {{24{dm_rdata[23]}}, dm_rdata[23:16]} : {24'b0, dm_rdata[23:16]};
                    2'b11: final_dm_rdata = mem_sign ? {{24{dm_rdata[31]}}, dm_rdata[31:24]} : {24'b0, dm_rdata[31:24]};
                endcase
            end
            2'b10: begin // lh / lhu
                case(alu_r[1])
                    1'b0: final_dm_rdata = mem_sign ? {{16{dm_rdata[15]}}, dm_rdata[15:0]}  : {16'b0, dm_rdata[15:0]};
                    1'b1: final_dm_rdata = mem_sign ? {{16{dm_rdata[31]}}, dm_rdata[31:16]} : {16'b0, dm_rdata[31:16]};
                endcase
            end
            default: ;
        endcase
    end

endmodule