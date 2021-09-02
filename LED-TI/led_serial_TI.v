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

`define k1(i,j,k) (31-(k + 4*j + 16*i))*4  //i: means which key set, j,k : means array's position
`define k2(i,j)    (15-(j + 4*i))*4

`define keyn(i,j,k)      key[`k1(i,j,k)+3:`k1(i,j,k)]
`define keyn_next(i,j,k) key_next[`k1(i,j,k)+3:`k1(i,j,k)]

`define staten(i,j)      state[`k2(i,j)+3:`k2(i,j)]
`define staten_next(i,j) state_next[`k2(i,j)+3:`k2(i,j)]


`define k3(i,j)    (15-(j + 4*i))*8
`define k4(i,j,k)  (31-(k + 4*j + 16*i))*8

`define staten_shared(i,j)      state_shared[`k3(i,j)+7:`k3(i,j)]
`define staten_shared_next(i,j) state_shared_next[`k3(i,j)+7:`k3(i,j)]

`define keyn_shared(i,j,k)      key_shared[`k4(i,j,k) + 7:`k4(i,j,k)]
`define keyn_shared_next(i,j,k) key_shared_next[`k4(i,j,k)+ 7:`k4(i,j,k)]


module led_serial
   (
    clk,
    reset,
    keyi, //128 bit key input
    datai, //64 bit plaintext input
    dataq, // 64 bit ciphertext output
    start,
    done);

   input clk;
   input reset;
   input  [127:0] keyi;
   input  [ 63:0] datai;
   output [ 63:0] dataq;
   input 	  start;
   output 	  done;
   
 
 /////////////////////////////////////////////////////////////////// 
 //Yuan: 8bit random number generator instantiate
 ///////////////////////////////////////////////////////////////////
   reg  [7:0]  mask;
   wire [7:0]  mask_wire;
   
   
   // instantiate 2 random number generator
    random core_0 (.clk (clk),.o (mask_wire[3:0]));
    random core_1 (.clk (clk),.o (mask_wire[7:4]));
	
	always @(posedge clk)
	begin
		mask <= mask_wire;
	end
///////////////////////////////////////////////////////////////////	

   

   // state
   reg [ 63:0] 	 state, state_next;
   reg [127:0] 	 key, key_next;
   reg [  5:0] 	 rc, rc_next;
   //Yuan add the new state_masked with 8bit one unit
   reg [127:0]   state_shared, state_shared_next;
   reg [255:0] 	 key_shared, key_shared_next;
   //Mo temp reg
   reg [7:0] 	temp_reg1;
   reg [7:0] 	temp_reg2;
   reg [7:0] 	temp_reg3;
   reg [7:0] 	temp_reg4;
   reg [7:0] 	temp_reg5;

   parameter CMD_IDLE = 4'h0;
   parameter CMD_LOAD = 4'h1;
   //Yuan: add the addshare state operation
   parameter CMD_ADDSHARE_NIBBLE = 4'h2;
   parameter CMD_ADDSHARE_KEY = 4'h3;
   //Yuan: add the addconstant and sbox state operation
   parameter CMD_ADDCONSTANT = 4'h4;
   parameter CMD_SBOX_CAL = 4'h5;
   parameter CMD_SBOX_SHIFT = 4'h6;

 
   parameter CMD_SHIFTROW = 4'h7;
   parameter CMD_MIXCOLCOMPUTE = 4'h8;
   parameter CMD_MIXCOLROTATE = 4'h9;
   parameter CMD_ADDKEY = 4'hA;
    parameter CMD_BACK_SHARE = 4'hb;
   reg [3:0] 	 cmd;

   parameter STATE_IDLE = 4'h0;
   parameter STATE_LOAD = 4'h1;

   parameter STATE_ADDSHARE_NIBBLE = 4'h2;
   parameter STATE_ADDSHARE_KEY = 4'h3;
   parameter STATE_INIT = 4'h4;

   parameter STATE_ADDCONSTANT= 4'h5;
   parameter STATE_SBOX_CAL= 4'h6;
   parameter STATE_SBOX_SHIFT= 4'h7;
  
   parameter STATE_SHIFTROW = 5'h8;
   parameter STATE_MIXCOL0 = 5'h9;
   parameter STATE_MIXCOL1 = 5'hA;
   parameter STATE_MIXCOL2 = 5'hB;
   parameter STATE_MIXCOL3 = 5'hC;
   parameter STATE_MIXCOL4 = 5'hD;
   parameter STATE_NEXTROUND = 5'hE;
   parameter STATE_ADDKEY = 5'hF;
   parameter STATE_NEXTSTEP = 5'h10;
   parameter STATE_BACK_SHARE = 5'h11;
   
   reg [4:0] 	 ctlstate, ctlstate_next;

   reg [3:0] 	 bcount, bcount_next;  // byte counter
   reg [3:0] 	 rcount, rcount_next;  // round counter
   reg [3:0] 	 scount, scount_next;  // step counter
   reg [4:0] 	 keycount, keycount_next; //Yuan: add keycounter 0->31 

 /////////////////////////////////////////////////////////////////// 
 //Sbox instantiate  
 ///////////////////////////////////////////////////////////////////   
   reg sbox_start;
   wire sbox_done;
   wire [7:0] sbox_out;
   
   sbox s( .clk(clk), .reset(reset), .nibblesi_8(`staten_shared(0,0)), .mask(mask), .start(sbox_start), .nibblesq_8(sbox_out), .done(sbox_done));  //Mo: connect sbox


   function [7:0] logic_round;
      input [7:0] d;
      input [7:0] k;
	  begin
	  logic_round = d ^ k;
	  end
   endfunction // sbox
//Yuan: duplicate the round constant for 4bit -> 8bit example 0010 --> 0010 0010

   function [7:0] logic_addconst_decode; 
      input [3:0] d;
      case (d)	
    	4'h0: logic_addconst_decode = {4'h8 ^ mask[3:0],mask[3:0]};
	4'h1: logic_addconst_decode = {{1'b0,rc[5:3]}^mask[3:0],mask[3:0]};
	4'h2: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'h3: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'h4: logic_addconst_decode = {4'h9 ^ mask[3:0],mask[3:0]};
	4'h5: logic_addconst_decode = {{1'b0,rc[2:0]}^mask[3:0],mask[3:0]};
	4'h6: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'h7: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'h8: logic_addconst_decode = {4'h2 ^ mask[3:0],mask[3:0]};
	4'h9: logic_addconst_decode = {{1'b0,rc[5:3]}^mask[3:0],mask[3:0]};
	4'ha: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'hb: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'hc: logic_addconst_decode = {4'h3 ^ mask[3:0],mask[3:0]};
	4'hd: logic_addconst_decode = {{1'b0,rc[2:0]}^mask[3:0],mask[3:0]};
	4'he: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
	4'hf: logic_addconst_decode = {4'h0 ^ mask[3:0],mask[3:0]};
      endcase // case (d)
   endfunction
   
   function automatic [3:0] logic_fmul2;
      input [3:0] d;
      logic_fmul2 = {d[2],d[1],d[3]^d[0],d[3]};
   endfunction // sbox

   function [3:0] logic_fmul4;
      input [3:0] d;
      logic_fmul4 = logic_fmul2(logic_fmul2(d));
   endfunction // sbox

   always @(posedge clk, posedge reset)
     if (reset)
       begin
	  ctlstate <= STATE_IDLE;
	  key      <= 128'h0;
	  key_shared <= 256'h0;
	  state    <= 64'h0;
	  state_shared <= 128'h0;
	  rc       <= 6'h1;
	  bcount   <= 4'h0;
	  rcount   <= 4'h0;
	  scount   <= 4'h0;
      keycount <= 5'h0;  //Yuan
	  temp_reg1 <= 8'h0;
	  temp_reg2 <= 8'h0;
	  temp_reg3 <= 8'h0;
	  temp_reg4 <= 8'h0;
	  temp_reg5 <= 8'h0;
	  sbox_start <= 1'b0;
       end
     else
       begin
	  ctlstate <= ctlstate_next;
	  key      <= key_next;
	  key_shared <= key_shared_next;
	  state    <= state_next;
	  state_shared <= state_shared_next;
	  rc       <= rc_next;
	  bcount   <= bcount_next;
	  rcount   <= rcount_next;
	  scount   <= scount_next;	 
      keycount <= keycount_next;//Yuan 
       end

   // control logic
   always @(*)
     begin

	// default
	bcount_next   = bcount;
	rcount_next   = rcount;
	scount_next   = scount;
	keycount_next = keycount;
	ctlstate_next = ctlstate;
	cmd           = CMD_IDLE;

	case (ctlstate)
	  STATE_IDLE:
	    begin
	       cmd = CMD_IDLE;
	       bcount_next = 4'h0;
	       rcount_next = 4'h0;
	       scount_next = 4'h0;
	       ctlstate_next = start ? STATE_LOAD : STATE_IDLE;	       
	    end
	  STATE_LOAD:
	    begin
	       cmd = CMD_LOAD;
	       ctlstate_next = STATE_ADDSHARE_NIBBLE; //Yuan	       
	    end
	//////////////////////////////////////////////////////////////////////
	//  Yuan: sharing for nibble
	//////////////////////////////////////////////////////////////////////
	   STATE_ADDSHARE_NIBBLE:
	    begin
	       cmd = CMD_ADDSHARE_NIBBLE;
		   
	       bcount_next = (bcount == 4'hf) ? 4'h0 : (bcount + 1);
	       ctlstate_next = (bcount == 4'hf) ? STATE_ADDSHARE_KEY :STATE_ADDSHARE_NIBBLE;	
               
	    end
	////////////////////////////////////////////////////////////////////
	//  Yuan: add sharing for key
	//////////////////////////////////////////////////////////////////////
	   STATE_ADDSHARE_KEY:
	    begin
	       cmd = CMD_ADDSHARE_KEY;
		   
	       keycount_next   = (keycount == 5'h1f) ? 5'h0 : (keycount + 1); // Yuan: count number to 32
	       ctlstate_next = (keycount == 5'h1f) ? STATE_INIT : STATE_ADDSHARE_KEY;	
               
	    end
	////////////////////////////////////////////////////////////////////
	  
	  STATE_INIT:	//the initial add key
	    begin
	       cmd = CMD_ADDKEY;
	       
	       bcount_next = (bcount == 4'hf) ? 4'h0 : (bcount + 1);
	       ctlstate_next = (bcount == 4'hf) ? STATE_ADDCONSTANT : STATE_INIT;	       
	    end
     /////////////////////////////////////////////////////////////////////////
	 // Yuan: STATE_ADDCONSTANT
	 /////////////////////////////////////////////////////////////////////////
	 STATE_ADDCONSTANT:
	    begin
	       cmd = CMD_ADDCONSTANT;
	       bcount_next = (bcount == 4'hf) ? 4'h0 : (bcount + 1);
	       ctlstate_next = (bcount == 4'hf) ? STATE_SBOX_CAL: STATE_ADDCONSTANT;	       
	    end
	 //STATE_DUMMY:  //Mo: I don't remember the reason for waiting one cycle.
	 //  begin
	//	   ctlstate_next = STATE_SBOX_CAL;
	 //  end
	 /////////////////////////////////////////////////////////////////////////
	 // Yuan: STATE_SBOX
	 /////////////////////////////////////////////////////////////////////////
	 STATE_SBOX_CAL:
	     begin
	      
		   cmd = CMD_SBOX_CAL;
		   sbox_start = 1 ;
		   ctlstate_next = (sbox_done==1)? STATE_SBOX_SHIFT : STATE_SBOX_CAL;
	    end

	 STATE_SBOX_SHIFT:
	     begin
	       cmd = CMD_SBOX_SHIFT;
		   sbox_start = 0;  
	       bcount_next = (bcount == 4'hf) ? 4'h0 : (bcount + 1);
	       ctlstate_next = (bcount == 4'hf) ? STATE_SHIFTROW : STATE_SBOX_CAL;	       
	    end
	  STATE_SHIFTROW:
	    begin
	       cmd = CMD_SHIFTROW;
	       ctlstate_next = STATE_MIXCOL0;	       
	    end
	  STATE_MIXCOL0:
	    begin
	       cmd = CMD_MIXCOLCOMPUTE;
	       ctlstate_next = STATE_MIXCOL1;	       
	    end
	  STATE_MIXCOL1:
	    begin
	       cmd = CMD_MIXCOLCOMPUTE;
	       ctlstate_next = STATE_MIXCOL2;	       
	    end
	  STATE_MIXCOL2:
	    begin
	       cmd = CMD_MIXCOLCOMPUTE;
	       ctlstate_next = STATE_MIXCOL3;	       
	    end
	  STATE_MIXCOL3:
	    begin
	       cmd = CMD_MIXCOLCOMPUTE;
	       ctlstate_next = STATE_MIXCOL4;	       
	    end
	  STATE_MIXCOL4:
	    begin
	       cmd = CMD_MIXCOLROTATE;
	       bcount_next = (bcount == 4'h3) ? 4'h0 : (bcount + 1);
	       ctlstate_next = (bcount == 4'h3) ? STATE_NEXTROUND : STATE_MIXCOL0;
	    end
	  STATE_NEXTROUND:
	    begin
	       rcount_next = (rcount == 4'h3) ? 4'h0 : (rcount + 1);
	       ctlstate_next = (rcount == 4'h3) ? STATE_ADDKEY : STATE_ADDCONSTANT;
	    end
	  STATE_ADDKEY:
	    begin
	       cmd = CMD_ADDKEY;
	       bcount_next = (bcount == 4'hf) ? 4'h0 : (bcount + 1);
	       ctlstate_next = (bcount == 4'hf) ? STATE_NEXTSTEP : STATE_ADDKEY;
	    end
	  STATE_NEXTSTEP:
	    begin
	       scount_next = (scount == 4'hb) ? 4'h0 : (scount + 1);
	       ctlstate_next = (scount == 4'hb) ? STATE_BACK_SHARE: STATE_ADDCONSTANT;	       
	    end
	  STATE_BACK_SHARE:
	    begin
		   cmd = CMD_BACK_SHARE;
	       bcount_next = (bcount == 4'hf) ? 4'h0 : (bcount + 1);
		   ctlstate_next = (bcount == 4'hf) ? STATE_IDLE : STATE_BACK_SHARE;
		end
		   
	    
	endcase // case (state)
     end

   assign done = (ctlstate == STATE_IDLE);
   assign dataq = state_next;   
     
   // datapath
   always @(*)
     begin
	// default
	state_next = state;
	state_shared_next = state_shared;
	key_next      = key;
	key_shared_next = key_shared;
 	rc_next       = rc;
	case (cmd)
	  CMD_IDLE:
	    begin
	    end
	  CMD_LOAD:
	    begin
	       key_next = keyi;
	       state_next = datai;	       
	    end
	   	
	  CMD_ADDSHARE_NIBBLE:
	      begin
	       `staten_shared_next(3,3) = {`staten(0,0) ^ mask[3:0],mask[3:0]};
		   
		   `staten_shared_next(3,2) = `staten_shared(3,3);
	       `staten_shared_next(3,1) = `staten_shared(3,2);
	       `staten_shared_next(3,0) = `staten_shared(3,1);    
	       `staten_shared_next(2,3) = `staten_shared(3,0);
	       `staten_shared_next(2,2) = `staten_shared(2,3);
	       `staten_shared_next(2,1) = `staten_shared(2,2);
	       `staten_shared_next(2,0) = `staten_shared(2,1);
	       `staten_shared_next(1,3) = `staten_shared(2,0);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(0,3) = `staten_shared(1,0);
	       `staten_shared_next(0,2) = `staten_shared(0,3);
	       `staten_shared_next(0,1) = `staten_shared(0,2);
	       `staten_shared_next(0,0) = `staten_shared(0,1);
		   
	       `staten_next(3,3) = 4'b0;
	       `staten_next(3,2) = `staten(3,3);
	       `staten_next(3,1) = `staten(3,2);
	       `staten_next(3,0) = `staten(3,1);    
	       `staten_next(2,3) = `staten(3,0);
	       `staten_next(2,2) = `staten(2,3);
	       `staten_next(2,1) = `staten(2,2);
	       `staten_next(2,0) = `staten(2,1);
	       `staten_next(1,3) = `staten(2,0);
	       `staten_next(1,2) = `staten(1,3);
	       `staten_next(1,1) = `staten(1,2);
	       `staten_next(1,0) = `staten(1,1);
	       `staten_next(0,3) = `staten(1,0);
	       `staten_next(0,2) = `staten(0,3);
	       `staten_next(0,1) = `staten(0,2);
	       `staten_next(0,0) = `staten(0,1);
		   
		end
		  
    CMD_ADDSHARE_KEY:   
		begin
	       `keyn_shared_next(1,3,3) = {`keyn(0,0,0) ^ mask[7:4],mask[7:4]};
	       `keyn_shared_next(1,0,0) = `keyn_shared(1,0,1); 
	       `keyn_shared_next(1,0,1) = `keyn_shared(1,0,2); 
	       `keyn_shared_next(1,0,2) = `keyn_shared(1,0,3); 
	       `keyn_shared_next(1,0,3) = `keyn_shared(1,1,0); 
	       `keyn_shared_next(1,1,0) = `keyn_shared(1,1,1); 
	       `keyn_shared_next(1,1,1) = `keyn_shared(1,1,2); 
	       `keyn_shared_next(1,1,2) = `keyn_shared(1,1,3); 
	       `keyn_shared_next(1,1,3) = `keyn_shared(1,2,0); 
	       `keyn_shared_next(1,2,0) = `keyn_shared(1,2,1); 
	       `keyn_shared_next(1,2,1) = `keyn_shared(1,2,2); 
	       `keyn_shared_next(1,2,2) = `keyn_shared(1,2,3); 
	       `keyn_shared_next(1,2,3) = `keyn_shared(1,3,0); 
	       `keyn_shared_next(1,3,0) = `keyn_shared(1,3,1); 
	       `keyn_shared_next(1,3,1) = `keyn_shared(1,3,2); 
	       `keyn_shared_next(1,3,2) = `keyn_shared(1,3,3); 
		   
	       `keyn_shared_next(0,0,0) = `keyn_shared(0,0,1); 
	       `keyn_shared_next(0,0,1) = `keyn_shared(0,0,2); 
	       `keyn_shared_next(0,0,2) = `keyn_shared(0,0,3); 
	       `keyn_shared_next(0,0,3) = `keyn_shared(0,1,0); 
	       `keyn_shared_next(0,1,0) = `keyn_shared(0,1,1); 
	       `keyn_shared_next(0,1,1) = `keyn_shared(0,1,2); 
	       `keyn_shared_next(0,1,2) = `keyn_shared(0,1,3); 
	       `keyn_shared_next(0,1,3) = `keyn_shared(0,2,0); 
	       `keyn_shared_next(0,2,0) = `keyn_shared(0,2,1); 
	       `keyn_shared_next(0,2,1) = `keyn_shared(0,2,2); 
	       `keyn_shared_next(0,2,2) = `keyn_shared(0,2,3); 
	       `keyn_shared_next(0,2,3) = `keyn_shared(0,3,0); 
	       `keyn_shared_next(0,3,0) = `keyn_shared(0,3,1); 
	       `keyn_shared_next(0,3,1) = `keyn_shared(0,3,2); 
	       `keyn_shared_next(0,3,2) = `keyn_shared(0,3,3); 
	       `keyn_shared_next(0,3,3) = `keyn_shared(1,0,0); 
		   
	       		   
		   //4 bit key nipple update
	       `keyn_next(0,0,0) = `keyn(0,0,1); 
	       `keyn_next(0,0,1) = `keyn(0,0,2); 
	       `keyn_next(0,0,2) = `keyn(0,0,3); 
	       `keyn_next(0,0,3) = `keyn(0,1,0); 
	       `keyn_next(0,1,0) = `keyn(0,1,1); 
	       `keyn_next(0,1,1) = `keyn(0,1,2); 
	       `keyn_next(0,1,2) = `keyn(0,1,3); 
	       `keyn_next(0,1,3) = `keyn(0,2,0); 
	       `keyn_next(0,2,0) = `keyn(0,2,1); 
	       `keyn_next(0,2,1) = `keyn(0,2,2); 
	       `keyn_next(0,2,2) = `keyn(0,2,3); 
	       `keyn_next(0,2,3) = `keyn(0,3,0); 
	       `keyn_next(0,3,0) = `keyn(0,3,1); 
	       `keyn_next(0,3,1) = `keyn(0,3,2); 
	       `keyn_next(0,3,2) = `keyn(0,3,3); 
	       `keyn_next(0,3,3) = `keyn(1,0,0); 
		   
	       `keyn_next(1,0,0) = `keyn(1,0,1); 
	       `keyn_next(1,0,1) = `keyn(1,0,2); 
	       `keyn_next(1,0,2) = `keyn(1,0,3); 
	       `keyn_next(1,0,3) = `keyn(1,1,0); 
	       `keyn_next(1,1,0) = `keyn(1,1,1); 
	       `keyn_next(1,1,1) = `keyn(1,1,2); 
	       `keyn_next(1,1,2) = `keyn(1,1,3); 
	       `keyn_next(1,1,3) = `keyn(1,2,0); 
	       `keyn_next(1,2,0) = `keyn(1,2,1); 
	       `keyn_next(1,2,1) = `keyn(1,2,2); 
	       `keyn_next(1,2,2) = `keyn(1,2,3); 
	       `keyn_next(1,2,3) = `keyn(1,3,0); 
	       `keyn_next(1,3,0) = `keyn(1,3,1); 
	       `keyn_next(1,3,1) = `keyn(1,3,2); 
	       `keyn_next(1,3,2) = `keyn(1,3,3); 
	       `keyn_next(1,3,3) = 4'b0;
	    end   
	        
	  CMD_ADDKEY:
	    begin
	       `staten_shared_next(3,3) = `staten_shared(0,0) ^ `keyn_shared(0,0,0);
	       `staten_shared_next(3,2) = `staten_shared(3,3);
	       `staten_shared_next(3,1) = `staten_shared(3,2);
	       `staten_shared_next(3,0) = `staten_shared(3,1);    
	       `staten_shared_next(2,3) = `staten_shared(3,0);
	       `staten_shared_next(2,2) = `staten_shared(2,3);
	       `staten_shared_next(2,1) = `staten_shared(2,2);
	       `staten_shared_next(2,0) = `staten_shared(2,1);
	       `staten_shared_next(1,3) = `staten_shared(2,0);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(0,3) = `staten_shared(1,0);
	       `staten_shared_next(0,2) = `staten_shared(0,3);
	       `staten_shared_next(0,1) = `staten_shared(0,2);
	       `staten_shared_next(0,0) = `staten_shared(0,1);
	       
	       `keyn_shared_next(0,0,0) = `keyn_shared(0,0,1); 
	       `keyn_shared_next(0,0,1) = `keyn_shared(0,0,2); 
	       `keyn_shared_next(0,0,2) = `keyn_shared(0,0,3); 
	       `keyn_shared_next(0,0,3) = `keyn_shared(0,1,0); 
	       `keyn_shared_next(0,1,0) = `keyn_shared(0,1,1); 
	       `keyn_shared_next(0,1,1) = `keyn_shared(0,1,2); 
	       `keyn_shared_next(0,1,2) = `keyn_shared(0,1,3); 
	       `keyn_shared_next(0,1,3) = `keyn_shared(0,2,0); 
	       `keyn_shared_next(0,2,0) = `keyn_shared(0,2,1); 
	       `keyn_shared_next(0,2,1) = `keyn_shared(0,2,2); 
	       `keyn_shared_next(0,2,2) = `keyn_shared(0,2,3); 
	       `keyn_shared_next(0,2,3) = `keyn_shared(0,3,0); 
	       `keyn_shared_next(0,3,0) = `keyn_shared(0,3,1); 
	       `keyn_shared_next(0,3,1) = `keyn_shared(0,3,2); 
	       `keyn_shared_next(0,3,2) = `keyn_shared(0,3,3); 
	       `keyn_shared_next(0,3,3) = `keyn_shared(1,0,0);
		   
	       `keyn_shared_next(1,0,0) = `keyn_shared(1,0,1); 
	       `keyn_shared_next(1,0,1) = `keyn_shared(1,0,2); 
	       `keyn_shared_next(1,0,2) = `keyn_shared(1,0,3); 
	       `keyn_shared_next(1,0,3) = `keyn_shared(1,1,0); 
	       `keyn_shared_next(1,1,0) = `keyn_shared(1,1,1); 
	       `keyn_shared_next(1,1,1) = `keyn_shared(1,1,2); 
	       `keyn_shared_next(1,1,2) = `keyn_shared(1,1,3); 
	       `keyn_shared_next(1,1,3) = `keyn_shared(1,2,0); 
	       `keyn_shared_next(1,2,0) = `keyn_shared(1,2,1); 
	       `keyn_shared_next(1,2,1) = `keyn_shared(1,2,2); 
	       `keyn_shared_next(1,2,2) = `keyn_shared(1,2,3); 
	       `keyn_shared_next(1,2,3) = `keyn_shared(1,3,0); 
	       `keyn_shared_next(1,3,0) = `keyn_shared(1,3,1); 
	       `keyn_shared_next(1,3,1) = `keyn_shared(1,3,2); 
	       `keyn_shared_next(1,3,2) = `keyn_shared(1,3,3); 
	       `keyn_shared_next(1,3,3) = `keyn_shared(0,0,0);
	    end
	//Yuan	
	  CMD_ADDCONSTANT:	 
	    begin
	       `staten_shared_next(3,3) = logic_round(`staten_shared(0,0), logic_addconst_decode(bcount)); // add the constant
	       `staten_shared_next(3,2) = `staten_shared(3,3);
	       `staten_shared_next(3,1) = `staten_shared(3,2);
	       `staten_shared_next(3,0) = `staten_shared(3,1);    
	       `staten_shared_next(2,3) = `staten_shared(3,0);
	       `staten_shared_next(2,2) = `staten_shared(2,3);
	       `staten_shared_next(2,1) = `staten_shared(2,2);
	       `staten_shared_next(2,0) = `staten_shared(2,1);
	       `staten_shared_next(1,3) = `staten_shared(2,0);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(0,3) = `staten_shared(1,0);
	       `staten_shared_next(0,2) = `staten_shared(0,3);
	       `staten_shared_next(0,1) = `staten_shared(0,2);
	       `staten_shared_next(0,0) = `staten_shared(0,1);
	    end

	 CMD_SBOX_CAL:
		begin //Mo: do nothing here. `staten_shared(0,0) already connect to sbox input.
			//sbox_input = `staten_shared(0,0);
		end
	  

	 CMD_SBOX_SHIFT:
		begin 
		   `staten_shared_next(3,3) = sbox_out;
	       `staten_shared_next(3,2) = `staten_shared(3,3);
	       `staten_shared_next(3,1) = `staten_shared(3,2);
	       `staten_shared_next(3,0) = `staten_shared(3,1);    
	       `staten_shared_next(2,3) = `staten_shared(3,0);
	       `staten_shared_next(2,2) = `staten_shared(2,3);
	       `staten_shared_next(2,1) = `staten_shared(2,2);
	       `staten_shared_next(2,0) = `staten_shared(2,1);
	       `staten_shared_next(1,3) = `staten_shared(2,0);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(0,3) = `staten_shared(1,0);
	       `staten_shared_next(0,2) = `staten_shared(0,3);
	       `staten_shared_next(0,1) = `staten_shared(0,2);
	       `staten_shared_next(0,0) = `staten_shared(0,1);	  
		end
	  
	  CMD_SHIFTROW:
	    begin
	       rc_next = {rc[4:0], (1'b1 ^ rc[4] ^ rc[5])}; //update roundconstant and do shiftrow
	       `staten_shared_next(0,0) = `staten_shared(0,0);
	       `staten_shared_next(0,1) = `staten_shared(0,1);
	       `staten_shared_next(0,2) = `staten_shared(0,2);
	       `staten_shared_next(0,3) = `staten_shared(0,3);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,3) = `staten_shared(1,0);
	       `staten_shared_next(2,0) = `staten_shared(2,2);
	       `staten_shared_next(2,1) = `staten_shared(2,3);
	       `staten_shared_next(2,2) = `staten_shared(2,0);
	       `staten_shared_next(2,3) = `staten_shared(2,1);
	       `staten_shared_next(3,0) = `staten_shared(3,3);
	       `staten_shared_next(3,1) = `staten_shared(3,0);
	       `staten_shared_next(3,2) = `staten_shared(3,1);
	       `staten_shared_next(3,3) = `staten_shared(3,2);	       
	    end
	  CMD_MIXCOLCOMPUTE:
	    begin
	       `staten_shared_next(0,0) = `staten_shared(1,0);
	       `staten_shared_next(1,0) = `staten_shared(2,0);
	       `staten_shared_next(2,0) = `staten_shared(3,0);
		   // Yuan: divide the nibble input two shares and do addmixcolumn calculation
		   temp_reg1 = `staten_shared(0,0);
		   temp_reg2 = `staten_shared(1,0);
		   temp_reg3 = `staten_shared(2,0);
		   temp_reg4 = `staten_shared(3,0);
		   
	       temp_reg5[7:4] = logic_fmul4(temp_reg1[7:4]) ^
				   temp_reg2[7:4] ^
				   logic_fmul2(temp_reg3[7:4]) ^
				   logic_fmul2(temp_reg4[7:4]);

			temp_reg5[3:0] = logic_fmul4(temp_reg1[3:0]) ^
				   temp_reg2[3:0] ^
				   logic_fmul2(temp_reg3[3:0]) ^
				   logic_fmul2(temp_reg4[3:0]);
				   
			`staten_shared_next(3,0) = temp_reg5;
	    end
	  CMD_MIXCOLROTATE:
	    begin
	       `staten_shared_next(0,0) = `staten_shared(0,1);
	       `staten_shared_next(0,1) = `staten_shared(0,2);
	       `staten_shared_next(0,2) = `staten_shared(0,3);
	       `staten_shared_next(0,3) = `staten_shared(0,0);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,3) = `staten_shared(1,0);
	       `staten_shared_next(2,0) = `staten_shared(2,1);
	       `staten_shared_next(2,1) = `staten_shared(2,2);
	       `staten_shared_next(2,2) = `staten_shared(2,3);
	       `staten_shared_next(2,3) = `staten_shared(2,0);
	       `staten_shared_next(3,0) = `staten_shared(3,1);
	       `staten_shared_next(3,1) = `staten_shared(3,2);
	       `staten_shared_next(3,2) = `staten_shared(3,3);
	       `staten_shared_next(3,3) = `staten_shared(3,0);
	    end
		
		CMD_BACK_SHARE:
	    begin
		   temp_reg1 = `staten_shared(0,0);
	      `staten_next(3,3) = temp_reg1[7:4]^temp_reg1[3:0];
		  
	       `staten_next(3,2) = `staten(3,3);
	       `staten_next(3,1) = `staten(3,2);
	       `staten_next(3,0) = `staten(3,1);    
	       `staten_next(2,3) = `staten(3,0);
	       `staten_next(2,2) = `staten(2,3);
	       `staten_next(2,1) = `staten(2,2);
	       `staten_next(2,0) = `staten(2,1);
	       `staten_next(1,3) = `staten(2,0);
	       `staten_next(1,2) = `staten(1,3);
	       `staten_next(1,1) = `staten(1,2);
	       `staten_next(1,0) = `staten(1,1);
	       `staten_next(0,3) = `staten(1,0);
	       `staten_next(0,2) = `staten(0,3);
	       `staten_next(0,1) = `staten(0,2);
	       `staten_next(0,0) = `staten(0,1);
		   
		   `staten_shared_next(3,3) = 8'h0;
		   `staten_shared_next(3,2) = `staten_shared(3,3);
	       `staten_shared_next(3,1) = `staten_shared(3,2);
	       `staten_shared_next(3,0) = `staten_shared(3,1);    
	       `staten_shared_next(2,3) = `staten_shared(3,0);
	       `staten_shared_next(2,2) = `staten_shared(2,3);
	       `staten_shared_next(2,1) = `staten_shared(2,2);
	       `staten_shared_next(2,0) = `staten_shared(2,1);
	       `staten_shared_next(1,3) = `staten_shared(2,0);
	       `staten_shared_next(1,2) = `staten_shared(1,3);
	       `staten_shared_next(1,1) = `staten_shared(1,2);
	       `staten_shared_next(1,0) = `staten_shared(1,1);
	       `staten_shared_next(0,3) = `staten_shared(1,0);
	       `staten_shared_next(0,2) = `staten_shared(0,3);
	       `staten_shared_next(0,1) = `staten_shared(0,2);
	       `staten_shared_next(0,0) = `staten_shared(0,1);
		  
	    end
	endcase
     end
   
endmodule
   
