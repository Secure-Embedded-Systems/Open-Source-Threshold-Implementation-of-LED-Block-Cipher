
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

module tff(q,t,c);
    output q;
    input t,c;
    reg q;
    initial 
     begin 
      q=1'b1;
     end
    always @ (posedge c)
    begin
        if (t==1'b0) begin q=q; end
        else begin q=~q;  end
    end
endmodule
 
module tff1(q,t,c);
    output q;
    input t,c;
    reg q;
    initial 
     begin 
      q=1'b0;
     end
    always @ (posedge c)
    begin
        if (t==1'b0) begin q=q; end
        else begin q=~q;  end
    end
endmodule
 
module random(o,clk);
    output [3:0]o;      input clk;
    xor (t0,o[3],o[2]);
    assign t1=o[0];
    assign t2=o[1];
    assign t3=o[2];
    tff u1(o[0],t0,clk);
    tff1 u2(o[1],t1,clk);
    tff1 u3(o[2],t2,clk);
    tff1 u4(o[3],t3,clk);
endmodule