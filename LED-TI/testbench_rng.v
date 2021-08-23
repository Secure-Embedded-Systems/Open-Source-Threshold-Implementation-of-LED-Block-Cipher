module rng_test;

   reg clk;
   reg vrst, rst, rd;
   wire rng_out;
   
   shift shift_1(.clk(clk),
		  .rst(rst),
		  .vrst(vrst),
		  .rd(rd),
		  .rng_out(rng_out));
   
   always
     #50
       clk = ~clk;

   initial
     begin
	clk = 0;
	rst = 0;
	vrst =1;
	rd =0;
	
	#500
	  vrst = 0;
	#500
	  vrst = 1;

	#100 rd = 1'h1;
	//#400 rd = 1'h0;
	
	#10000
$stop;
 end
endmodule
   