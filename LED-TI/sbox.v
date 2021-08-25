
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

module sbox
	(
    clk,
    reset,
    nibblesi_8,
	mask,
	start,
    nibblesq_8,
	done
	);

   input clk;
   input reset;
   input [7:0] nibblesi_8;
   input [7:0] mask;
   input 	  start;
   output [7:0]  nibblesq_8;
   output reg done;
   
   reg [ 11:0] nibblesq_12;
   reg [ 11:0] nibblesq_12_next;
   reg [3:0] y1;
   reg [3:0] y2;
   reg [3:0] y3;
   reg [3:0] y1_next;
   reg [3:0] y2_next;
   reg [3:0] y3_next;

   wire [3:0] n1;
   wire [3:0] n2;
   wire [3:0] n3;

   assign n1[3:0] = mask[3:0] ^ mask[7:4]; // m3 xor m4
   assign n2[3:0] = nibblesi_8[7:4] ^ mask[7:4];
   assign n3[3:0] = nibblesi_8[3:0] ^ mask[3:0];

   assign nibblesq_8[7:4] = nibblesq_12[11:8];
   assign nibblesq_8[3:0] = nibblesq_12[7:4] ^ nibblesq_12[3:0];

	parameter STATE_IDLE = 4'h0;
	parameter STATE_SBOXG = 4'h1;
	parameter STATE_SBOXF = 4'h2;
	parameter STATE_FINISH = 4'h3;
	reg [3:0] 	 ctlstate, ctlstate_next;
   


	function [3:0] G1;  
	input [7:0] G1input;
	begin
		G1[3] = G1input[6]^G1input[5]^G1input[4]; //g13 = y2+z2+w2
		G1[2] = 1'b1^G1input[6]^G1input[5]; //g12 = 1+y2+z2	
		G1[1] = 1'b1^G1input[7]^G1input[5]^(G1input[6]&G1input[4])^(G1input[6]&G1input[0])^(G1input[2]&G1input[4])^(G1input[5]&G1input[4])^(G1input[5]&G1input[0])^(G1input[1]&G1input[4]); //g11 = 1 +x2 + z2 +y2w2 + y2w3 +y3w2 +z2w2 + z2w3 + z3w2,
		G1[0] = 1'b1^G1input[4]^(G1input[7]&G1input[6])^(G1input[7]&G1input[2])^(G1input[3]&G1input[6])^(G1input[7]&G1input[5])^(G1input[7]&G1input[1])^(G1input[3]&G1input[5])^(G1input[6]&G1input[5])^(G1input[6]&G1input[1])^(G1input[2]&G1input[5]); //g10 = 1 +w2 + x2y2 +x2y3 + x3y2 +x2z2 +x2z3 +x3z2 +y2z2 +y2z3 +y3z2
	end
	endfunction
	
	function [3:0] G2;  //call: G2({n1[3:0],n3[3:0]})
	input [7:0] G2input;
	begin
		G2[3] = G2input[2]^G2input[1]^G2input[0]; //g23 = y3 +z3 + w3,
		G2[2] = G2input[2]^G2input[1]; //g22 = y3 + z3,	
		G2[1] = G2input[3]^G2input[1]^(G2input[2]&G2input[0])^(G2input[2]&G2input[4])^(G2input[6]&G2input[0])^(G2input[1]&G2input[0])^(G2input[1]&G2input[4])^(G2input[5]&G2input[0]); //g21 = x3 + z3 + y3w3 + y1w3 + y3w1 +z3w3 + z1w3 + z3w1,
		G2[0] = G2input[0]^(G2input[3]&G2input[2])^(G2input[3]&G2input[6])^(G2input[7]&G2input[2])^(G2input[3]&G2input[1])^(G2input[3]&G2input[5])^(G2input[7]&G2input[1])^(G2input[2]&G2input[1])^(G2input[2]&G2input[5])^(G2input[6]&G2input[1]); //g10 = 1 +w2 + x2y2 +x2y3 + x3y2 +x2z2 +x2z3 +x3z2 +y2z2 +y2z3 +y3z2
	end
	endfunction
	
	function [3:0] G3;  //call: G3({n1[3:0],n2[3:0]})
	input [7:0] G3input;
	begin
		G3[3] = G3input[6]^G3input[5]^G3input[4]; //g33 = y1 +z1 + w1,
		G3[2] = G3input[6]^G3input[5]; //g32 = y1 + z1,	
		G3[1] = G3input[7]^G3input[5]^(G3input[6]&G3input[4])^(G3input[6]&G3input[0])^(G3input[2]&G3input[4])^(G3input[5]&G3input[4])^(G3input[5]&G3input[0])^(G3input[1]&G3input[4]); //g31 = x1 +z1 + y1w1 +y1w2 + y2w1 +z1w1 +z1w2 + z2w1,
		G3[0] = G3input[4]^(G3input[7]&G3input[6])^(G3input[7]&G3input[2])^(G3input[3]&G3input[6])^(G3input[7]&G3input[5])^(G3input[7]&G3input[1])^(G3input[3]&G3input[5])^(G3input[6]&G3input[5])^(G3input[6]&G3input[1])^(G3input[2]&G3input[5]); //g30 = w1 +x1y1 +x1y2 +x2y1 + x1z1 + x1z2 +x2z1 +y1z1 +y1z2 +y2z1;
	end
	endfunction
	
	function [3:0] F1;  //call: F1({y3[3:0],y2[3:0]})
	input [7:0] F1input;
	begin
		F1[3] = F1input[6]^F1input[5]^F1input[4]^(F1input[7]&F1input[4])^(F1input[7]&F1input[0])^(F1input[3]&F1input[4]);	//f13 = y2 +z2 +w2 +x2w2 + x2w3 +x3w2
		F1[2] = F1input[7]^(F1input[5]&F1input[4])^(F1input[5]&F1input[0])^(F1input[1]&F1input[4]);	//f12 = x2 +z2w2 +z2w3 +z3w2,
		F1[1] = F1input[6]^F1input[5]^(F1input[7]&F1input[4])^(F1input[7]&F1input[0])^(F1input[3]&F1input[4]);	//f11 = y2 +z2 +x2w2 +x2w3 +x3w2,
		F1[0] = F1input[5]^(F1input[6]&F1input[4])^(F1input[6]&F1input[0])^(F1input[2]&F1input[4]);	//f10 = z2 +y2w2 + y2w3 +y3w2;
	end
	endfunction
	
	function [3:0] F2;  //call: F2({y3[3:0],y1[3:0]})
	input [7:0] F2input;
	begin
		F2[3] = F2input[2]^F2input[1]^F2input[0]^(F2input[3]&F2input[0])^(F2input[3]&F2input[4])^(F2input[7]&F2input[0]);	//f23 = y3 +z3 +w3 +x3w3 + x1w3 +x3w1
		F2[2] = F2input[3]^(F2input[1]&F2input[0])^(F2input[1]&F2input[4])^(F2input[5]&F2input[0]);	//f22 = x3 +z3w3 +z1w3 +z3w1
		F2[1] = F2input[2]^F2input[1]^(F2input[3]&F2input[0])^(F2input[3]&F2input[4])^(F2input[7]&F2input[0]);	//f21 = y3 +z3 +x3w3 +x1w3 +x3w1,
		F2[0] = F2input[1]^(F2input[2]&F2input[0])^(F2input[6]&F2input[0])^(F2input[2]&F2input[4]);	//f20 = z3 +y3w3 + y1w3 +y3w1;
	end
	endfunction
	
	function [3:0] F3;  //call: F3({y2[3:0],y1[3:0]})
	input [7:0] F3input;
	begin	
		F3[3] = F3input[6]^F3input[5]^F3input[4]^(F3input[7]&F3input[4])^(F3input[7]&F3input[0])^(F3input[3]&F3input[4]);	//f23 = y3 +z3 +w3 +x3w3 + x1w3 +x3w1
		F3[2] = F3input[7]^(F3input[5]&F3input[4])^(F3input[5]&F3input[0])^(F3input[1]&F3input[4]);	//f22 = x3 +z3w3 +z1w3 +z3w1
		F3[1] = F3input[6]^F3input[5]^(F3input[7]&F3input[4])^(F3input[7]&F3input[0])^(F3input[3]&F3input[4]);	//f21 = y3 +z3 +x3w3 +x1w3 +x3w1,
		F3[0] = F3input[5]^(F3input[6]&F3input[4])^(F3input[6]&F3input[0])^(F3input[2]&F3input[4]);	//f20 = z3 +y3w3 + y1w3 +y3w1;
	end
	endfunction
	
	
	always @(posedge clk, posedge reset)
	if (reset)
	begin
		ctlstate <= STATE_IDLE;
		nibblesq_12 <= 12'h0;
		y1 <= 4'h0;
		y2 <= 4'h0;
		y3 <= 4'h0;

		done <= 0;
	end
	else
	begin
		ctlstate <= ctlstate_next;
		nibblesq_12 <= nibblesq_12_next;
		y1 <= y1_next;
		y2 <= y2_next;
		y3 <= y3_next; 

	end
	
	// control logic
	always @(*)
	begin

	// default
	y1_next   = y1;
	y2_next   = y2;
	y3_next   = y3;
	ctlstate_next = ctlstate;
	nibblesq_12_next = nibblesq_12;

	case (ctlstate)
		STATE_IDLE:
		begin
			ctlstate_next = start ? STATE_SBOXG : STATE_IDLE;
			done = 0;
		end
		STATE_SBOXG:
		begin
				
			y1_next = G1({n2[3:0],n3[3:0]});
			y2_next = G2({n1[3:0],n3[3:0]});
			y3_next = G3({n1[3:0],n2[3:0]});
			ctlstate_next = STATE_SBOXF;
		end
		STATE_SBOXF:
		begin
			nibblesq_12_next[3:0] = F1({y2[3:0],y1[3:0]});	//s1
			nibblesq_12_next[7:4] = F2({y3[3:0],y1[3:0]}); //s2
			nibblesq_12_next[11:8] = F3({y3[3:0],y2[3:0]}); //s3			
			ctlstate_next = STATE_FINISH;
		end
		STATE_FINISH:
		begin
			done = 1;
			ctlstate_next = STATE_IDLE;
		end
		
	endcase
	end

endmodule
   
