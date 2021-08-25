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

module shift (vrst, rst, clk, rng_out, rd); 
input vrst,rst, clk, rd; 
output [7:0] rng_out; 
reg [31:0] out_tmp;
reg [31:0] tmp0;
reg [31:0] tmp1;
reg [31:0] tmp2;
reg [31:0] tmp3;

reg [31:0] tmp0_reg;
reg [31:0] tmp1_reg;
reg [31:0] tmp2_reg;

reg [2:0] cnt;
reg cnt_en;
reg cnt_rst;

parameter seed = 32'h8e20a6e5; 

assign rng_out = out_tmp[7:0];
 
 always @ (*) 
    begin 
      tmp1 = tmp0_reg^(tmp0_reg << 13); 
      tmp2 = tmp1^(tmp1 >> 17);
      tmp3 = tmp2^(tmp2 << 5);	  
    end 

 always @ (posedge clk) 
   if (~vrst)
   begin
	tmp0_reg <= seed;
	tmp1_reg <= 32'h0;
	tmp2_reg <= 32'h0;
	out_tmp  <= 32'h0;
	cnt_en <= 1'b0;
	cnt <= 0;
   end
   else if(rst)
   begin
    tmp0_reg <= tmp0_reg;
    out_tmp <= out_tmp;
	cnt_en <= 1'b0;
	cnt_rst <= 1'b0;
	cnt <= 0;

   end
   else begin
     if (rd)
      begin 
		cnt <= cnt + 1;
	    if (cnt == 3'h3) begin
	      	out_tmp <= tmp3;
	    end
	    if (cnt == 3'h2) begin
	      	tmp0_reg <= tmp3;
	    end
	    if (cnt == 3'h3) begin
		cnt <= 0;
	    end
	   if (cnt < 3'h3) begin
	      	out_tmp <= out_tmp >> 8;	   
	    end
       
     end 
	 else begin
		cnt <= cnt;
	   	out_tmp <= tmp3;
	 end
   end
endmodule

