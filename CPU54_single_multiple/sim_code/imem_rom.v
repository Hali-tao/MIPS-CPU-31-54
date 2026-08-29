`timescale 1ns / 1ps

module imem_rom(
    input [10:0] addr,   // 输入：指令地址
    output [31:0] inst    // 输出：指令内容
    );

parameter IMEM_FILE = "1_addi.hex.txt";
reg [31:0] mem [0:2047];

initial begin
    $readmemh({"D:/CPU54/test/", IMEM_FILE}, mem);
end

assign inst = mem[addr];

endmodule