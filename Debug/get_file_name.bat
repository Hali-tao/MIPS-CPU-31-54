@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 清空输出文件
cd. > test_file_name.txt

:: 1. 遍历所有 .hex.txt 文件，去掉双后缀，并暂时一行一个写入临时文件
if exist temp_sort.txt del temp_sort.txt
for %%f in (*.hex.txt) do (
    set "temp_name=%%~nf"
    echo !temp_name:~0,-4! >> temp_sort.txt
)

:: 2. 核心：调用 PowerShell 对文本进行「智能数字排序」，并转换为单行空格分隔
if exist temp_sort.txt (
    powershell -Command "(Get-Content temp_sort.txt) | Sort-Object { [System.Convert]::ToDouble(($_.Split('_')[0])) } | ForEach-Object { $OFS=' '; \"$_\" } | Out-String" > temp_res.txt
    
    :: 3. 将最终排序好的一行数据读入并写入目标文件（顺便去掉末尾换行符）
    set /p final_list=<temp_res.txt
    echo !final_list! > test_file_name.txt
    
    :: 清理临时文件
    del temp_sort.txt
    del temp_res.txt
)

echo 已完成！所有 .hex.txt 文件名已按数字顺序输出到 test_file_name.txt
echo 格式：用空格分隔
pause