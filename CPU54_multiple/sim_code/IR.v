module ir (
    input clk,
    input rst,// active high
    input IRin,
    input [31:0] im_inst,
    output reg [31:0] inst
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            inst <= 32'b0;
        end else if (IRin) begin
            inst <= im_inst;
        end
    end
endmodule
