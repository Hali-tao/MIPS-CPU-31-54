`timescale 1ns / 1ps

module imem(
    input [10:0] addr,   // 输入：指令地址
    output [31:0] inst    // 输出：指令内容
    );

dist_mem_gen_0 imem (
  .a(addr),      // 输入：地址
  .spo(inst)     // 输出：指令内容
);

endmodule
// `ifdef SIM
//     reg [31:0] mem [0:2047];
//     reg [8*256-1:0] imem_file;
//     reg [8*512-1:0] line;
//     integer imem_fd;
//     integer i;
//     integer line_no;
//     integer code;

//     initial begin
//         if (!$value$plusargs("IMEM=%s", imem_file)) begin
//             imem_file = "D:/CPU31/CPU31.srcs/sources_1/new/test/_1_addi.coe";
//         end
//         $display("SIM: loading imem from %s", imem_file);
//         for (i = 0; i < 2048; i = i + 1) begin
//             mem[i] = 32'h00000000;
//         end
//         imem_fd = $fopen(imem_file, "r");
//         if (imem_fd == 0) begin
//             $display("ERROR: Cannot open IMEM file %s", imem_file);
//             $finish;
//         end
//         line_no = 0;
//         while (!$feof(imem_fd)) begin
//             if ($fgets(line, imem_fd) == 0) begin
//                 break;
//             end
//             code = $sscanf(line, "%h", mem[line_no]);
//             if (code == 1) begin
//                 line_no = line_no + 1;
//             end
//         end
//         $fclose(imem_fd);
//         for (i = 0; i < 16; i = i + 1) begin
//             $display("IMEM[%0d] = %08h", i, mem[i]);
//         end
//     end

//     assign inst = mem[addr];
// `else
//     dist_mem_gen_0 imem (
//       .a(addr),      // 输入：地址
//       .spo(inst)     // 输出：指令内容
//     );
// `endif