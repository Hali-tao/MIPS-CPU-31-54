module z_reg (
    input clk,
    input rst,
    input [31:0] data,
    input Zin,
    output reg [31:0] z_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            z_out <= 32'h0;
        end else if (Zin) begin
            z_out <= data;
        end
    end
endmodule
