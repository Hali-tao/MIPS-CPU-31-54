`timescale 1ns / 1ps

module ext(
    input [15:0] imm_16,
    input ext_op,// 0: zero-extend, 1: sign-extend
    output [31:0] imm_32
    );

assign imm_32 = ext_op ? {{16{imm_16[15]}}, imm_16} : {16'b0, imm_16};

endmodule
