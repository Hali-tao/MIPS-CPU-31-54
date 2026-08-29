#include <iostream>
#include <string>
#include <vector>
#include <cstdint>
#include <iomanip>
#include <bitset>  // 用于输出二进制

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "使用方法: " << argv[0] << " <16进制指令机器码1> [16进制指令机器码2 ...]\n";
        std::cout << "例如: " << argv[0] << " 00851820 0xac040005\n";
        return 1;
    }

    for (int i = 1; i < argc; ++i) {
        std::string hex_str = argv[i];
        uint32_t inst = 0;

        try {
            inst = std::stoul(hex_str, nullptr, 16);
        } catch (...) {
            std::cerr << "错误: 无法解析输入 '" << hex_str << "' 为16进制数。\n";
            continue;
        }

        // ==================== 1. 核心字段切片提取 ====================
        uint8_t op    = (inst >> 26) & 0x3F; // inst[31:26]
        uint8_t rs    = (inst >> 21) & 0x1F; // inst[25:21]
        uint8_t rt    = (inst >> 16) & 0x1F; // inst[20:16]
        uint8_t rd    = (inst >> 11) & 0x1F; // inst[15:11] (R型专用)
        uint16_t imm  = inst & 0xFFFF;        // inst[15:0]  (I型专用)
        uint8_t func  = inst & 0x3F;         // inst[5:0]   (R型专用)

        // ==================== 2. 大类前置译码基准线 ====================
        bool op_r      = (op == 0x00); 
        bool op_cp0    = (op == 0x10); 
        bool op_regimm = (op == 0x01); 

        std::string name = "UNKNOWN_OR_UNSUPPORTED";
        int type_flag = 0; // 0: 其它/未知, 1: R型, 2: I型

        // ==================== 3. 指令独热码匹配 ====================
        
        // 1. R型 算术逻辑指令
        if      (op_r && (func == 0x20)) { name = "add";   type_flag = 1; }
        else if (op_r && (func == 0x21)) { name = "addu";  type_flag = 1; }
        else if (op_r && (func == 0x22)) { name = "sub";   type_flag = 1; }
        else if (op_r && (func == 0x23)) { name = "subu";  type_flag = 1; }
        else if (op_r && (func == 0x24)) { name = "and";   type_flag = 1; }
        else if (op_r && (func == 0x25)) { name = "or";    type_flag = 1; }
        else if (op_r && (func == 0x26)) { name = "xor";   type_flag = 1; }
        else if (op_r && (func == 0x27)) { name = "nor";   type_flag = 1; }
        else if (op_r && (func == 0x2A)) { name = "slt";   type_flag = 1; }
        else if (op_r && (func == 0x2B)) { name = "sltu";  type_flag = 1; }
        
        // 2. R型 移位指令
        else if (op_r && (func == 0x00)) { name = "sll";   type_flag = 1; } // 空指令 0x00000000 译码为 sll
        else if (op_r && (func == 0x02)) { name = "srl";   type_flag = 1; }
        else if (op_r && (func == 0x03)) { name = "sra";   type_flag = 1; }
        else if (op_r && (func == 0x04)) { name = "sllv";  type_flag = 1; }
        else if (op_r && (func == 0x06)) { name = "srlv";  type_flag = 1; }
        else if (op_r && (func == 0x07)) { name = "srav";  type_flag = 1; }
        
        // 3. R型 跳转指令
        else if (op_r && (func == 0x08)) { name = "jr";    type_flag = 1; }
        else if (op_r && (func == 0x09)) { name = "jalr";  type_flag = 1; }
        
        // 4. R型 乘除法与HI/LO寄存器指令
        else if (op_r && (func == 0x18)) { name = "mult";  type_flag = 1; }
        else if (op_r && (func == 0x19)) { name = "multu"; type_flag = 1; }
        else if (op_r && (func == 0x1A)) { name = "div";   type_flag = 1; }
        else if (op_r && (func == 0x1B)) { name = "divu";  type_flag = 1; }
        else if (op_r && (func == 0x10)) { name = "mfhi";  type_flag = 1; }
        else if (op_r && (func == 0x12)) { name = "mflo";  type_flag = 1; }
        else if (op_r && (func == 0x11)) { name = "mthi";  type_flag = 1; }
        else if (op_r && (func == 0x13)) { name = "mtlo";  type_flag = 1; }
        
        // 5. R型 异常指令
        else if (op_r && (func == 0x0C)) { name = "syscall"; type_flag = 1; }
        else if (op_r && (func == 0x0D)) { name = "break";   type_flag = 1; }
        else if (op_r && (func == 0x34)) { name = "teq";     type_flag = 1; }
        
        // 6. J型 跳转指令 (不属于R或I)
        else if (op == 0x02) name = "j";
        else if (op == 0x03) name = "jal";
        
        // 7. I型 算术逻辑指令
        else if (op == 0x08) { name = "addi";  type_flag = 2; }
        else if (op == 0x09) { name = "addiu"; type_flag = 2; }
        else if (op == 0x0C) { name = "andi";  type_flag = 2; }
        else if (op == 0x0D) { name = "ori";   type_flag = 2; }
        else if (op == 0x0E) { name = "xori";  type_flag = 2; }
        else if (op == 0x0F) { name = "lui";   type_flag = 2; }
        
        // 8. I型 比较与分支指令
        else if (op == 0x0A) { name = "slti";  type_flag = 2; }
        else if (op == 0x0B) { name = "sltiu"; type_flag = 2; }
        else if (op == 0x04) { name = "beq";   type_flag = 2; }
        else if (op == 0x05) { name = "bne";   type_flag = 2; }
        else if (op_regimm && (rt == 0x01)) { name = "bgez"; type_flag = 2; }
        
        // 9. I型 内存读取指令
        else if (op == 0x23) { name = "lw";  type_flag = 2; }
        else if (op == 0x20) { name = "lb";  type_flag = 2; }
        else if (op == 0x24) { name = "lbu"; type_flag = 2; }
        else if (op == 0x21) { name = "lh";  type_flag = 2; }
        else if (op == 0x25) { name = "lhu"; type_flag = 2; }
        
        // 10. I型 内存写入指令
        else if (op == 0x2B) { name = "sw";  type_flag = 2; }
        else if (op == 0x28) { name = "sb";  type_flag = 2; }
        else if (op == 0x29) { name = "sh";  type_flag = 2; }
        
        // 11. CP0 相关指令
        else if (op_cp0 && (rs == 0x00)) name = "mfc0";
        else if (op_cp0 && (rs == 0x04)) name = "mtc0";
        else if (op_cp0 && (rs == 0x10) && (func == 0x18)) name = "eret";
        
        // 12. CLZ 前导零指令
        else if ((op == 0x1C) && (func == 0x20)) name = "clz";

        // ==================== 4. 格式化输出结果 ====================
        // 先打印基础信息
        std::cout << std::right;
        std::cout << "0x" << std::hex << std::setw(8) << std::setfill('0') << inst ;
        std::cout << std::setfill(' ') << " -> " << std::left << std::setw(8) << name;
        
        // 恢复成十进制输出
        std::cout << std::dec; 

        if (type_flag == 1) {
            // R型：输出十进制的 rs, rt, rd
            std::cout << " [R-Type] rs: " << (int)rs 
                      << ", rt: " << (int)rt 
                      << ", rd: " << (int)rd;
        } 
        else if (type_flag == 2) {
            // I型：输出十进制的 rs, rt，以及二进制的 imm
            std::cout << " [I-Type] rs: " << (int)rs 
                      << ", rt: " << (int)rt 
                      << ", imm: 0b" << std::bitset<16>(imm);
        }
        else{
            std::cout << " rs: "  << (int)rs 
                      << ", rt: " << (int)rt 
                      << ", rd: " << (int)rd;
        }
        std::cout << "\n";
    }

    return 0;
}