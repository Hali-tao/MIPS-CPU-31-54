`timescale 1ns / 1ps

module dmem(
    input clk,
    input ena,
    input re,
    input we,
    input [10:0] addr,
    input [31:0] wdata,
    output [31:0] rdata
    );

reg [31:0] dm [31:0];
// 读取用异步
assign rdata = (ena && re && !we) ? dm[addr] : 32'bz;

// 写入用同步
always @(negedge clk) begin
    if(ena && we) begin
        dm[addr] <= wdata;
    end
end

endmodule
