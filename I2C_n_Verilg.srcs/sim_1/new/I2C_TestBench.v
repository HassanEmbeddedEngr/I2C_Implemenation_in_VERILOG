`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/24/2024 11:32:19 AM
// Design Name: 
// Module Name: I2C_TestBench
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module I2C_TestBench();
reg clk =0; 
reg reset = 0;
reg newd = 0;
reg [6:0] addr = 0;
reg op = 0;
reg [7:0] din;
wire [7:0] dout;
wire sda,scl;
wire busy;
wire ack_err;

I2C_Protocol dut (
        clk, reset, newd,
        din,
        addr,
        op,      
        sda,   
        scl, 
        dout,
        busy,
        ack_err,
        done
 );

always #1 clk = ~clk;

initial begin
reset = 1'b1;
repeat(5) @(posedge clk);
reset = 0;
newd = 1;
op = 0;
addr = 7'b1111000;
din = 8'hff;
@(negedge busy);
repeat(5) @(posedge clk);
//$stop;
end
endmodule
