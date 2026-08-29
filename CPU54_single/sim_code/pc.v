`timescale 1ns / 1ps

module pc(
    input clk,
    input rst,// active high
    input [31:0] npc,
    output reg [31:0] pc
    );

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= 32'h0040_0000;
    end else begin
        pc <= npc;
    end
end
endmodule