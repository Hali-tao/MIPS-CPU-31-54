@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ==================================================
echo               仿真 54 条指令
echo ==================================================

:: ===================== 54条完整测试列表 =====================
set "TEST_LIST=1_addi 2_addiu 3_andi 4_ori 5_sltiu 6_lui 7_xori 8_slti 9_addu 10_and"
set "TEST_LIST=%TEST_LIST% 11_beq 12_bne 13_j 14_jal 15_jr 16.26_lwsw 16.26_lwsw2"
set "TEST_LIST=%TEST_LIST% 17_xor 18_nor 19_or 20_sll 21_sllv 22_sltu 23_sra 24_srl"
set "TEST_LIST=%TEST_LIST% 25_subu 27_add 28_sub 29_slt 30_srlv 31_srav 32_clz"
set "TEST_LIST=%TEST_LIST% 33_divu 35_jalr 36.39_lbsb 36.39_lbsb2 37_lbu 37_lbu2"
set "TEST_LIST=%TEST_LIST% 38_lhu 38_lhu2 40.41_lhsh 40.41_lhsh2 42.45_mfc0mtc0"
set "TEST_LIST=%TEST_LIST% 43.46_mfhi.mthi 44.47_mflo.mtlo 48_mult 49_multu 52_bgez 54_div"

:: 遍历所有测试用例
for %%t in (%TEST_LIST%) do (
    echo.
    echo ==================================================
    echo                正在运行：%%t
    echo ==================================================

    :: 调用 ModelSim 命令行，自动传指令名，自动跑，自动退出
    vsim -c -do "vlog +define+TEST_NAME=\"%%t\" *.v; vsim -t 1ps _246tb_ex7_tb; run -all; quit"
    
    echo %%t 运行结束
)

echo.
echo ==================================================
echo               全部 54 条指令仿真完成！
echo ==================================================
pause