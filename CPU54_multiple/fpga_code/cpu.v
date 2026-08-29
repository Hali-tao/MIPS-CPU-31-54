// 文件名：cpu.v
// 功能：单周期MIPS CPU顶层模块（全面集成54条指令、精细化访存及CP0中断处理）
module cpu(
    input clk,
    input ena,
    input rst,
    input [31:0] im_inst,
    input [31:0] dm_rdata,     // 从外挂DMEM读回的全字数据 (32位)
    input intr,                // 外部硬件中断请求

    output dm_ena,
    output reg [3:0] dm_we,    // 4位字节写使能 (供外挂BRAM使用)
    output dm_re,
    output [31:0] dm_addr,     // 内存地址 (需由外部模块截取 >> 2)
    output reg [31:0] dm_wdata,// 处理后的内存写入数据

    output [31:0] pc_out,
    output update_pc
);
    // CU 输出控制信号
    wire PCin, IRin, Zin;
    wire reg_write;
    wire ext_sign;
    wire [1:0] mem_size;
    wire mem_sign;
    wire mem_read, mem_write;
    wire [3:0] aluc;
    wire mfc0,mtc0,hi_w,lo_w;
    // 多路选择器信号
    wire [1:0] rf_waddr_sel, alu_src_A, alu_src_B;
    wire z_in_sel, hi_src, lo_src;
    wire [2:0] rf_wdata_sel,pc_src;

    // IR信号
    wire [31:0] inst;
    // IR拆分信号
    wire [4:0] rs = inst[25:21];
    wire [4:0] rt = inst[20:16];
    wire [4:0] rd = inst[15:11];
    wire [15:0] imm_16 = inst[15:0];
    wire [4:0] shamt = inst[10:6];

    // regfile信号
    wire [31:0] rdata1, rdata2;
    wire [31:0] wdata;
    wire [4:0] waddr;

    // pc信号
    wire [31:0] pc_next,pc;

    // z寄存器信号
    wire [31:0] z_out;
    wire [31:0] z_in_data;

    // cp0信号
    wire [31:0] cp0_rdata, cp0_status, cp0_exc_addr;
    wire cp0_timer_int;
    wire [31:0] cp0_epc;
    wire exception, inst_eret;
    wire [4:0] exc_cause;

    // clz信号
    wire [31:0] clz_out;

    // ext信号
    wire [31:0] imm_32;

    // alu信号
    wire [31:0] alu_a, alu_b, alu_r;
    wire zero;

    // hilo信号
    wire [31:0] hi_out, lo_out;
    wire [31:0] hi_in, lo_in;

    // md信号
    wire [1:0] md_op;
    wire [31:0] md_hi, md_lo;

    // ls信号
    reg  [31:0] final_dm_rdata; // 访存处理后的读数据

    // pc更新
    wire pc_update;

    // ==================== IR模块实例化 ====================
    ir u_ir(
        .clk(clk), .rst(rst), .IRin(IRin),
        .im_inst(im_inst), .inst(inst)
    );

    // ==================== regfile模块实例化 ====================
    regfile cpu_ref(
        // input
        .clk(clk), .ena(ena), .rst(rst),
        .wena(reg_write),
        .raddr1(rs), .raddr2(rt), 
        .waddr(waddr), .wdata(wdata),
        // output
        .rdata1(rdata1), .rdata2(rdata2)
    );
    assign waddr = rf_waddr_sel == 2'b00 ? 5'd31 : // jal
                rf_waddr_sel == 2'b01 ? rd : // R型指令 jalr
                rf_waddr_sel == 2'b10 ? rt : 5'd0; // I型指令
    assign wdata = rf_wdata_sel == 3'b000 ? cp0_rdata : // cp0
                rf_wdata_sel == 3'b001 ? final_dm_rdata : // load_dm
                rf_wdata_sel == 3'b010 ? z_out : // z
                rf_wdata_sel == 3'b011 ? pc : // pc
                rf_wdata_sel == 3'b100 ? hi_out : // hi
                rf_wdata_sel == 3'b101 ? lo_out : // lo
                z_out; // default

    // ==================== PC模块实例化 ====================
    pc u_pc(.clk(clk), .rst(rst), .PCin(PCin), .npc(pc_next), .pc(pc));
    assign pc_next = pc_src == 3'b000 ? z_out : // z
                     pc_src == 3'b001 ? {pc[31:28], inst[25:0], 2'b00} : // jump
                     pc_src == 3'b010 ? cp0_exc_addr : // exc_addr
                     pc_src == 3'b011 ? rdata1 : // jump reg
                     pc_src == 3'b100 ? cp0_epc : // eret
                     z_out; // default
    
    // ==================== Z寄存器模块实例化 ====================
    z_reg u_z_reg(.clk(clk), .rst(rst), .data(z_in_data), .Zin(Zin),.z_out(z_out));
    assign z_in_data = z_in_sel ? alu_r : clz_out;

    // ==================== CP0模块实例化 ====================
    CP0 u_cp0(
        // input
        .clk(clk), .rst(rst),
        .mfc0(mfc0), .mtc0(mtc0),
        .pc(pc), .Rd(rd), .wdata(rdata2),
        .exception(exception), .eret(inst_eret), .cause(exc_cause), .intr(intr),
        // output
        .rdata(cp0_rdata), .status(cp0_status), .timer_int(cp0_timer_int), 
        .exc_addr(cp0_exc_addr), .epc_out(cp0_epc)
    );

    // ==================== CLZ模块实例化 ====================
    clz u_clz(.in(rdata1), .out(clz_out)); 

    // ==================== EXT模块实例化 ====================
    ext u_ext(.imm_16(imm_16), .ext_op(ext_sign), .imm_32(imm_32));

    // ==================== ALU模块实例化 ====================
    alu u_alu(.a(alu_a), .b(alu_b), .aluc(aluc), .r(alu_r), 
        .zero(zero), .carry(), .negative(), .overflow());

    assign alu_a = alu_src_A == 2'b00 ? {27'b0, shamt}: // shamt
                   alu_src_A == 2'b01 ? rdata1: // rs
                   alu_src_A == 2'b10 ? pc : // pc
                   32'b0; // default
    assign alu_b = alu_src_B == 2'b00 ? rdata2 : // rt
                     alu_src_B == 2'b01 ? imm_32 : // imm
                     alu_src_B == 2'b10 ? {imm_32[29:0], 2'b00} : // branch
                     32'd4; // 4
    

    // ==================== HILO模块实例化 ====================
    hilo_reg u_hilo(
        .clk(clk), 
        .rst(rst), 
        .hi_we(hi_w),
        .lo_we(lo_w),
        .hi_in(hi_in), 
        .lo_in(lo_in),
        .hi_out(hi_out), 
        .lo_out(lo_out)
    );
    assign hi_in = hi_src ? md_hi : rdata1;
    assign lo_in = lo_src ? md_lo : rdata1;

    // ==================== 优化的乘除法启动控制逻辑 ====================
    wire is_md_inst;
    wire md_busy;
    wire md_t3;
    reg  md_started;

    // 精确控制 md_started 的状态机辅助寄存器
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            md_started <= 1'b0;
        end else begin
            // 只有当在 T3 状态，且是乘除法指令，且计算尚未结束(md_busy)时保持或启动
            if (md_t3 && is_md_inst) begin
                md_started <= 1'b1; // 在 T3 的第一个时钟沿后立即锁存为 1
            end else begin
                md_started <= 1'b0; // 退出 T3 或非乘除法指令时清零，为下一条指令做准备
            end
        end
    end

    // 只有在 T3 状态的第一周期，且 md_started 还没来得及变 1 时，md_start 才为高
    assign md_start = md_t3 & is_md_inst & !md_started;

    // ==================== MD模块实例化 ====================
    mult_div u_md(
        .clk(clk),
        .reset(rst),
        .a(rdata1),
        .b(rdata2), 
        .mult_div_op(md_op), 
        .start(md_start),
        .hi_out(md_hi), 
        .lo_out(md_lo),
        .busy(md_busy)
    );

    // ==================== CU模块实例化 ====================
    cu u_cu(
        // input
        .clk(clk), .rst(rst), .inst(inst),
        .zero(zero), .neg(rdata1[31]), .busy(md_busy),
        .cp0_status(cp0_status), .intr(intr),
        // output
        .PCin(PCin), .IRin(IRin), .reg_write(reg_write),
        .ext_sign(ext_sign), .mem_size(mem_size), .mem_sign(mem_sign),
        .Zin(Zin), .aluc(aluc), .mem_read(mem_read), .mem_write(mem_write),
        .mfc0(mfc0), .mtc0(mtc0), .exception(exception), 
        .exc_cause(exc_cause), .eret(inst_eret),
        .hi_w(hi_w), .lo_w(lo_w), .md_op(md_op), .is_md_inst(is_md_inst), .md_t3(md_t3),
        .pc_update(pc_update),
        // 多路选择器信号
        .rf_waddr_sel(rf_waddr_sel), .alu_src_A(alu_src_A), .alu_src_B(alu_src_B),
        .z_in_sel(z_in_sel), .hi_src(hi_src), .lo_src(lo_src),
        .rf_wdata_sel(rf_wdata_sel), .pc_src(pc_src)
    );


    // ==================== 7. 精细化访存控制 (Byte Enable & Extraction) ====================
    assign dm_ena  = ena & (mem_write | mem_read) & ~exception;
    assign dm_re   = ena & mem_read & ~exception;
    assign dm_addr = z_out;
    
    // 写入控制 (sb, sh, sw)
    wire dm_we_base = ena & mem_write & ~exception;
    always @(*) begin
        dm_we = 4'b0000;
        dm_wdata = rdata2;
        if (dm_we_base) begin
            case(mem_size)
                2'b00: begin dm_we = 4'b1111; dm_wdata = rdata2; end // sw
                2'b10: begin // sh
                    if (z_out[1] == 1'b0) begin dm_we = 4'b0011; dm_wdata = {16'b0, rdata2[15:0]}; end
                    else                  begin dm_we = 4'b1100; dm_wdata = {rdata2[15:0], 16'b0}; end
                end
                2'b01: begin // sb
                    case(z_out[1:0])
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
                case(z_out[1:0])
                    2'b00: final_dm_rdata = mem_sign ? {{24{dm_rdata[7]}},  dm_rdata[7:0]}   : {24'b0, dm_rdata[7:0]};
                    2'b01: final_dm_rdata = mem_sign ? {{24{dm_rdata[15]}}, dm_rdata[15:8]}  : {24'b0, dm_rdata[15:8]};
                    2'b10: final_dm_rdata = mem_sign ? {{24{dm_rdata[23]}}, dm_rdata[23:16]} : {24'b0, dm_rdata[23:16]};
                    2'b11: final_dm_rdata = mem_sign ? {{24{dm_rdata[31]}}, dm_rdata[31:24]} : {24'b0, dm_rdata[31:24]};
                endcase
            end
            2'b10: begin // lh / lhu
                case(z_out[1])
                    1'b0: final_dm_rdata = mem_sign ? {{16{dm_rdata[15]}}, dm_rdata[15:0]}  : {16'b0, dm_rdata[15:0]};
                    1'b1: final_dm_rdata = mem_sign ? {{16{dm_rdata[31]}}, dm_rdata[31:16]} : {16'b0, dm_rdata[31:16]};
                endcase
            end
            default: ;
        endcase
    end

    assign pc_out = pc;
    assign update_pc = pc_update;
endmodule
