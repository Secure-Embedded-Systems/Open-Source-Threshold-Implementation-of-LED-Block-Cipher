/***************************************************************************************************/
/*
 * Virginia Tech
 * Secure Embedded Systems Lab
 *
 * Copyright (C) 2017 Virginia Tech
 *
 * Written in 2017 by Yuan Yao (yuan9@vt.edu), Mo Yang(ymo6@vt.edu), It is developed based on the 
 * bit-serial implmenetation of LED from Virginia Tech ECE_5520 Secure Hardware Design class material.
 *
 * This software is distributed under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version. We are in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */
 /**************************************************************************************************/

module led_serial_test;

   reg clk;
   reg reset;
   reg start;
   
   reg [127:0] keyi;
   reg [63:0] datai;

   wire [63:0] dataq;
   wire        done;
   
   led_serial dut(.clk(clk),
		  .reset(reset),
		  .keyi(keyi),
		  .datai(datai),
		  .dataq(dataq),
		  .start(start),
		  .done(done));
   
   always
     #50
       clk = ~clk;

   initial
     begin
	clk = 0;
	reset = 0;
	start = 0;
	
	#500
	  reset = 1;
	#500
	  reset = 0;
	keyi  = 128'h29cdbaabf2fbe3467cc254f81be8e78d;
	datai = 64'h67c6697351ff4aec;
	#100 start = 1'h1;
	#200 start = 1'h0;
	
	#1000000

	  reset = 1;
	#500
	  reset = 0;
	keyi  = 128'h66320db73158a35a255d051758e95ed4;
	datai = 64'h765a2e63339fc99a;
	#100 start = 1'h1;
	#200 start = 1'h0;

	#1000000

	  reset = 1;
	#500
	  reset = 0;
	keyi  = 128'h0e827441213ddc8770e93ea141e1fc67;
	datai = 64'habb2cdc69bb45411;
	#100 start = 1'h1;
	#200 start = 1'h0;
	 
     end

   always @(done)
     begin
	if (done == 1)
	  $display("Result %x", dataq);	
     end
   
endmodule
   
