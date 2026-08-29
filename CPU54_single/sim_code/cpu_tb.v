`timescale 1ns / 1ps
module cpu_tb;
reg clk;            //时钟信号
reg rst;            //复位信号
wire [31:0] inst;   //要执行的指令
wire [31:0] pc;     //下一条指令的地址
reg  [31:0] cnt;    //计数器，已经执行了几条指令

reg [8*256-1:0] result_file_name; // 结果输出文件路径
integer file_open;



`ifdef TEST_NAME
    parameter test_name = `TEST_NAME;
`else
    parameter test_name = "36.39_lbsb";  // 默认值
`endif

parameter file_name = {test_name,".hex.txt"};



initial 
begin
    clk = 1'b0;
    rst = 1'b1;
    cnt = 0;
    result_file_name = {"D:/CPU54/test/", test_name, "_tb.txt"};
    // result_file_name = {"D:/CPU54/coe_tb.txt"};
    
    // 先打开再关，以清空之前的内容
    file_open = $fopen(result_file_name, "w");
    $fclose(file_open);
    #50 rst = 1'b0;
end

always  #50 clk = ~clk;

always @ (posedge clk) begin
    cnt <= cnt + 1'b1;
    file_open = $fopen(result_file_name, "a+");
    //$fdisplay(file_open, "pc: %08h", sc_inst.pc - 32'h00400000); // 输出当前指令地址（减去基地址）
    $fdisplay(file_open, "pc: %08h", sc_inst.pc);
    $fdisplay(file_open, "instr: %08h", sc_inst.inst);
    //if (cnt == 450) begin
    if (cnt == 1319) begin
        $fdisplay(file_open, "SIM: cnt reached 450, stopping simulation");
        $fclose(file_open);
        $finish;
    end
    $fdisplay(file_open, "regfile0: %08h", sc_inst.sccpu.cpu_ref.array_reg[0]);
    $fdisplay(file_open, "regfile1: %08h", sc_inst.sccpu.cpu_ref.array_reg[1]);
    $fdisplay(file_open, "regfile2: %08h", sc_inst.sccpu.cpu_ref.array_reg[2]);
    $fdisplay(file_open, "regfile3: %08h", sc_inst.sccpu.cpu_ref.array_reg[3]);
    $fdisplay(file_open, "regfile4: %08h", sc_inst.sccpu.cpu_ref.array_reg[4]);
    $fdisplay(file_open, "regfile5: %08h", sc_inst.sccpu.cpu_ref.array_reg[5]);
    $fdisplay(file_open, "regfile6: %08h", sc_inst.sccpu.cpu_ref.array_reg[6]);
    $fdisplay(file_open, "regfile7: %08h", sc_inst.sccpu.cpu_ref.array_reg[7]);
    $fdisplay(file_open, "regfile8: %08h", sc_inst.sccpu.cpu_ref.array_reg[8]);
    $fdisplay(file_open, "regfile9: %08h", sc_inst.sccpu.cpu_ref.array_reg[9]);
    $fdisplay(file_open, "regfile10: %08h", sc_inst.sccpu.cpu_ref.array_reg[10]);
    $fdisplay(file_open, "regfile11: %08h", sc_inst.sccpu.cpu_ref.array_reg[11]);
    $fdisplay(file_open, "regfile12: %08h", sc_inst.sccpu.cpu_ref.array_reg[12]);
    $fdisplay(file_open, "regfile13: %08h", sc_inst.sccpu.cpu_ref.array_reg[13]);
    $fdisplay(file_open, "regfile14: %08h", sc_inst.sccpu.cpu_ref.array_reg[14]);
    $fdisplay(file_open, "regfile15: %08h", sc_inst.sccpu.cpu_ref.array_reg[15]);
    $fdisplay(file_open, "regfile16: %08h", sc_inst.sccpu.cpu_ref.array_reg[16]);
    $fdisplay(file_open, "regfile17: %08h", sc_inst.sccpu.cpu_ref.array_reg[17]);
    $fdisplay(file_open, "regfile18: %08h", sc_inst.sccpu.cpu_ref.array_reg[18]);
    $fdisplay(file_open, "regfile19: %08h", sc_inst.sccpu.cpu_ref.array_reg[19]);
    $fdisplay(file_open, "regfile20: %08h", sc_inst.sccpu.cpu_ref.array_reg[20]);
    $fdisplay(file_open, "regfile21: %08h", sc_inst.sccpu.cpu_ref.array_reg[21]);
    $fdisplay(file_open, "regfile22: %08h", sc_inst.sccpu.cpu_ref.array_reg[22]);
    $fdisplay(file_open, "regfile23: %08h", sc_inst.sccpu.cpu_ref.array_reg[23]);
    $fdisplay(file_open, "regfile24: %08h", sc_inst.sccpu.cpu_ref.array_reg[24]);
    $fdisplay(file_open, "regfile25: %08h", sc_inst.sccpu.cpu_ref.array_reg[25]);
    $fdisplay(file_open, "regfile26: %08h", sc_inst.sccpu.cpu_ref.array_reg[26]);
    $fdisplay(file_open, "regfile27: %08h", sc_inst.sccpu.cpu_ref.array_reg[27]);
    $fdisplay(file_open, "regfile28: %08h", sc_inst.sccpu.cpu_ref.array_reg[28]);
    $fdisplay(file_open, "regfile29: %08h", sc_inst.sccpu.cpu_ref.array_reg[29]);
    $fdisplay(file_open, "regfile30: %08h", sc_inst.sccpu.cpu_ref.array_reg[30]);
    $fdisplay(file_open, "regfile31: %08h", sc_inst.sccpu.cpu_ref.array_reg[31]);
    $fclose(file_open);
end

sccomp_dataflow 
#(
    .FILE_NAME(file_name)
)
sc_inst(
    .clk_in(clk),
    .reset(rst),
    .inst(inst),
    .pc(pc)
);

// sccomp_dataflow 
// sc_inst(
//     .clk_in(clk),
//     .reset(rst),
//     .inst(inst),
//     .pc(pc)
// );

endmodule