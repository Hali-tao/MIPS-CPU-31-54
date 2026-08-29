@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo =======================
echo       仿真31条指令
echo =======================

:: ===================== 你的完整测试列表 =====================
set "TEST_LIST=_1_addi _1_addiu _1_lui"
set "TEST_LIST=%TEST_LIST% _2_add _2_addu _2_and _2_andi _2_lwsw _2_lwsw2"
set "TEST_LIST=%TEST_LIST% _2_nor _2_or _2_ori _2_sll _2_sllv _2_slt"
set "TEST_LIST=%TEST_LIST% _2_slti _2_sltiu _2_sltu _2_sra _2_srav _2_srl"
set "TEST_LIST=%TEST_LIST% _2_srlv _2_sub _2_subu _2_xor _2_xori"
set "TEST_LIST=%TEST_LIST% _3.5_beq _3.5_bne _3_j _3_jal _4_jr"

REM set pass=0
REM set fail=0

:: 遍历所有测试用例
for %%t in (%TEST_LIST%) do (
    echo.
    echo ==================================================
    echo                    正在运行：%%t
    echo ==================================================

    :: 调用 ModelSim 命令行，自动传指令名，自动跑，自动退出
    vsim -c -do "vlog +define+TEST_NAME=\"%%t\" *.v; vsim -t 1ps cpu_tb; run -all; quit"
	
    echo %%t 运行结束
)

echo.
echo ==================================================
echo              全部指令仿真完成！
echo ==================================================