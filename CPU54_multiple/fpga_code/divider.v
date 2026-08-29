`timescale 1ns / 1ps

module divider(
    input clk,
    inout rst,
    output reg clk_out
    );
reg [31:0] cnt = 32'b0;
always @(posedge clk) begin
    if(rst)begin
        cnt <= 1'b0;
        clk_out <= 1'b0;
    end
    else begin 
        if(cnt == 32'd10000000)begin
            cnt <= 1'b0;
            clk_out <= ~clk_out;
        end
        else begin
            cnt <= cnt + 1'b1;
        end
    end
end

endmodule
