`timescale 1ns / 1ps

module CP0(
    input clk,
    input rst,
    input mfc0,              // CPU 指令 Mfc0, 读CP0
    input mtc0,              // CPU 指令 Mtc0, 写CP0
    input [31:0] pc,         // 当前指令PC，用于发生异常时保存
    input [4:0] Rd,          // 指定CP0的寄存器号(0~31)
    input [31:0] wdata,      // 数据从GP寄存器到CP0寄存器
    input exception,         // 内部异常触发信号 (syscall, break, teq)
    input eret,              // 指令ERET (Exception Return)
    input [4:0] cause,       // 异常原因码 (外部传入)
    input intr,              // 外部中断请求信号
    
    output reg [31:0] rdata, // 数据从 CP0 寄存器到GP寄存器
    output [31:0] status,    // 输出当前 status 状态
    output reg timer_int,    // 定时器中断
    output [31:0] exc_addr,  // 异常起始地址
    output [31:0] epc_out    // 输出 EPC 寄存器值，供 CPU 异常返回时使用
);

    // ==========================================
    // 1. 使用 2D 数组定义标准的 CP0 寄存器堆 (共32个32位寄存器)
    // ==========================================
    reg [31:0] cp0_regs [0:31];
    
    // 寄存器号常量定义，增强代码可读性
    localparam STATUS_IDX = 5'd12;
    localparam CAUSE_IDX  = 5'd13;
    localparam EPC_IDX    = 5'd14;

    // 硬件备份寄存器，用于响应异常时保存status状态，eret时恢复
    reg [31:0] status_bak;   

    // ==========================================
    // 2. 异常与中断的触发逻辑判断
    // ==========================================
    // 快捷组合信号：将当前寄存器堆中的 12 号 Status 值拉出来用于逻辑判断
    wire [31:0] current_status = cp0_regs[STATUS_IDX];
    
    // 规定: status[8] 屏蔽 syscall, status[9] 屏蔽 break, status[10] 屏蔽 teq, status[0] 为 IE
    wire ie_en   = current_status[0];
    wire sys_en  = ~current_status[8]  && ie_en;
    wire brk_en  = ~current_status[9]  && ie_en;
    wire teq_en  = ~current_status[10] && ie_en;
    
    // 组合判断各类异常是否真正生效
    wire is_syscall = exception && (cause == 5'd8)  && sys_en;
    wire is_break   = exception && (cause == 5'd9)  && brk_en;
    wire is_teq     = exception && (cause == 5'd13) && teq_en;
    wire is_intr    = intr && ie_en; 
    
    // 任意一个允许的异常或中断发生，就进入异常处理 
    wire enter_exc  = is_syscall || is_break || is_teq || is_intr;

    // ==========================================
    // 3. 组合逻辑输出
    // ==========================================
    assign status = cp0_regs[STATUS_IDX];
    assign exc_addr = 32'h0040_0004; // 实验规定：异常入口地址统一为 0x4
    assign epc_out = cp0_regs[EPC_IDX]; // 输出 EPC 寄存器值，供 CPU 异常返回时使用
    
    always @(*) begin
        timer_int = 1'b0; // 本次实验不实现定时器中断
    end

    // mfc0 读寄存器堆操作：完全支持 0~31 号任意寄存器的读取
    always @(*) begin
        if (mfc0) begin
            rdata = cp0_regs[Rd]; // 直接通过输入的 Rd 索引通用寄存器堆
        end else begin
            rdata = 32'b0;
        end
    end

    // ==========================================
    // 4. 时序逻辑：写寄存器堆与异常状态机
    // ==========================================
    integer i; // 用于复位循环
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 1. 复位时清空全部 32 个寄存器
            for (i = 0; i < 32; i = i + 1) begin
                cp0_regs[i] <= 32'b0;
            end
            // 2. 初始化 12 号 Status 寄存器：默认开启IE(位0)，并开启对异常的响应(位8,9,10)
            // cp0_regs[STATUS_IDX] <= 32'h0000_0701; 
            cp0_regs[STATUS_IDX] <= 32'b0;
            status_bak           <= 32'b0;
        end 
        else begin
            // 优先级 1: 发生异常/中断，进入异常处理 (硬件自动改写寄存器堆)
            if (enter_exc) begin
                // 将当前指令 PC 存入 14 号 EPC 寄存器
                cp0_regs[EPC_IDX] <= pc + 32'h0000_0004; // EPC 存储的是异常发生指令的下一条指令地址
                
                // 记录异常原因到 13 号 Cause 寄存器的 [6:2] 位 (ExcCode)
                if (is_intr) begin
                    cp0_regs[CAUSE_IDX][6:2] <= 5'b00000; // 外部中断，ExcCode设为0
                end else begin
                    cp0_regs[CAUSE_IDX][6:2] <= cause;    // 内部异常 记录传入的原因码
                end
                
                // 备份 12 号 Status，并将 Status 左移 5 位以关闭中断
                status_bak           <= cp0_regs[STATUS_IDX];
                cp0_regs[STATUS_IDX] <= {cp0_regs[STATUS_IDX][26:0], 5'b00000};
            end
            
            // 优先级 2: 异常返回 (ERET) (硬件自动恢复状态)
            else if (eret) begin
                // 从备份寄存器中恢复 12 号 Status 寄存器的原始状态
                cp0_regs[STATUS_IDX] <= status_bak;
            end
            
            // 优先级 3: 软件写寄存器 (mtc0) (完全支持 0~31 号任意寄存器的写入) 
            else if (mtc0) begin
                cp0_regs[Rd] <= wdata; // 直接通过输入的 Rd 写入对应的寄存器
            end
        end
    end

endmodule
