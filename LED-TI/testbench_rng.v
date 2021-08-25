/***************************************************************************************************/
/*
 * Virginia Tech
 * Secure Embedded Systems Lab
 *
 * Copyright (C) 2017 Virginia Tech
 *
 * Written in 2017 by Yuan Yao (yuan9@vt.edu), Mo Yang(ymo6@vt.edu)
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
	
	#10000
$stop;
 end
endmodule
   
