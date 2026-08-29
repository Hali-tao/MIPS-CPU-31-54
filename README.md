# MIPS-CPU-31-54

同济大学计算机组成原理课程设计  
MIPS CPU课程设计，从31条指令扩展到54条指令，包含乘除法多周期实现与FPGA验证

## 版本说明

| 目录 | 描述 | 状态 |
|------|------|------|
| `CPU31/` | 31条指令单周期CPU | ✅ 仿真/下板通过 |
| `CPU54_single/` | 54条指令单周期CPU（组合逻辑乘除） | ⚠️ 仿真通过，下板无法通过 |
| `CPU54_single_multiple/` | 54条指令单周期 + 多周期乘除（握手） | ✅ 仿真/下板通过 |
| `CPU54_multiple/` | 54条指令多周期CPU | ✅ 仿真/下板通过 |

```
## 目录结构

MIPS-CPU-31-54/
├── CPU31/                              # 31条指令单周期
│   ├── fpga_code/                      # FPGA下板代码
│   └── sim_code/                       # 仿真代码
│
├── CPU54_single/                       # 54指令单周期（组合逻辑乘除）
│   └── sim_code/                       # 仿真代码
│
├── CPU54_single_multiple/              # 单周期+多周期乘除
│   └── sim_code/                       # 仿真代码
│
├── CPU54_multiple/                     # 54指令多周期
│   ├── fpga_code/                      # FPGA下板代码
│   └── sim_code/                       # 仿真代码
│
├── Debug/                              # 辅助调试工具
│   ├── decoder.cpp                     # 指令解码器
│   ├── tc.cpp                          # 测试文本比对
│   ├── tc_m.cpp                        # 多周期测试文本比对
│   ├── run_tb-31.bat                   # 31指令仿真脚本
│   └── run_tb-54.bat                   # 54指令仿真脚本
│
├── CPU31.png                           # CPU31架构图
├── CPU31_操作时间表.xlsx                # CPU31时间表
├── CPU54_multiple.png                  # CPU54架构图
├── CPU54_多周期时间表.xlsx              # CPU54时间表
└── CPU54_状态转移图.png                 # CPU54状态图
```
