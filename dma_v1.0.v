`define IGNORE

module FifoBuffer(buff_out,empty,full,buff_in,wr_en,rd_en,clk,rst);

  input wire clk,rst,rd_en,wr_en;
  input wire[15:0] buff_in;         // 16 bit data in bus
  
  output wire empty,full;          // flags
  output wire[15:0] buff_out;      // FIFO out
   
  reg[2:0] rd_ptr ,wr_ptr;  // location pointer
  reg[3:0] count;           // current data count
  reg[15:0] buffer[7:0];    //  16 bit - 8 location

  assign empty = (count==0)? 1'b1:1'b0;
  assign full  = (count==8)? 1'b1:1'b0;
  
  always@(posedge clk or posedge rst)
    begin
      if(rst)
        count<=0;
      else if((!empty && rd_en)&&(!full && wr_en))
        count<=count;
      else if(!empty && rd_en)
        count<=count-1;
      else if(!full && wr_en)
        count<=count+1;
      else
        count<=count;
    end
  
  always@(posedge clk or posedge rst)
    begin
      if(rst)
       begin
        rd_ptr<=0;
        wr_ptr<=0;
       end
      else
       begin
         if(!empty && rd_en)
           rd_ptr<=rd_ptr+1;
         else
           rd_ptr<=rd_ptr;
         
         if(!full && wr_en)
           wr_ptr<=wr_ptr+1;
         else
           wr_ptr<=wr_ptr;
       end
    end
  
  always@(posedge clk)
    begin
      if(!full && wr_en)
        buffer[wr_ptr]<=buff_in;
      else
        buffer[wr_ptr]<=buffer[wr_ptr];
    end
  
 /*  always@(posedge clk or posedge rst)
    begin
      if(rst)
        out<=16'bx;
      else
        if(!empty && rd_en)
          out<=buffer[rd_ptr];
        else
          out<=out;
    end*/

  assign buff_out = (!empty && rd_en)? buffer[rd_ptr] : 16'hz;
 
endmodule 

module memory_int #(parameter 
           `ifdef IGNORE
                    DM_LOCATE="intmemload.mem",
           `endif
                    DMA_SIZE=3, DMD_SIZE=4)
			(
				input wire clk,
				input wire ps_dm_cslt,                // Data Memory Chip Select
				input wire ps_dm_wrb,                 // Data Memory Read/Write
				input wire[DMA_SIZE-1:0] dg_dm_add,   // Data Memory Address Bus
				input wire[DMD_SIZE-1:0] bc_dt,	      // Data Memory Data In
				output wire[DMD_SIZE-1:0] dm_bc_dt     // Data Memory Data Out
			);

 //------------------------------------------------------------------------------------------------------------------------
 //				DM reading and writing
 //------------------------------------------------------------------------------------------------------------------------
		integer file, i;

		reg [DMD_SIZE-1:0] dmData [(2**DMA_SIZE)-1:0];  //to store real data with adress discarded from text file
		reg [DMD_SIZE-1:0] dm [2*(2**DMA_SIZE)-1:0];	 //with address

		reg dm_cslt;
		reg dm_wrb;
		reg [DMA_SIZE-1:0] dm_add;
		wire [DMD_SIZE-1:0] dmBypData;

 `ifdef IGNORE
	//----------------------------------------------------------------------------------------
		//Initially open and close to clear the DM file
	/*	initial
		begin
			file=$fopen(DM_LOCATE,"w");
			$fclose(file);
		end*/
	
	//Comment above initial block if you want to access DM data present in data memory before startup.
	//----------------------------------------------------------------------------------------


		//initially load DM data from DM file (required when DM contains data to be read before startup)
		initial
		begin
			$readmemh(DM_LOCATE,dm);
			for(i=0; i<(2*(2**DMA_SIZE)); i=i+2)
			begin
				dmData[i/2]=dm[i+1];    //here address is to be discarded. Hence we read two words at a time
			end
		end 
 `endif

		//DM bypass
		//assign dmBypData = (dm_add==dg_dm_add) ? bc_dt : dmData[dg_dm_add];
		

		//DM reading
		/*always@(posedge clk)
		begin
			if(ps_dm_cslt && ~ps_dm_wrb)
			begin
					dm_bc_dt=dmData[dg_dm_add];
			end
		end*/
		assign dm_bc_dt= (ps_dm_cslt && ~ps_dm_wrb)? dmData[dg_dm_add]: 16'hz ;

		//control signal latching for writing purpose only ( Write to memory at execute+1 cycle)
		always@(posedge clk)
		begin
     if(ps_dm_wrb && ps_dm_cslt)
      begin
			dm_cslt <= ps_dm_cslt;
			dm_wrb  <= ps_dm_wrb;
			dm_add  <= dg_dm_add;
      end
		end

		//DM writing
		always@(posedge clk )
		begin
			if(dm_cslt)
			begin
				if(dm_wrb)
				begin
					dmData[dm_add][DMD_SIZE-1:0] <= bc_dt ;
 `ifdef IGNORE
					file=$fopen(DM_LOCATE);
					for(i=0; i<(2**DMA_SIZE); i=i+1)
					begin
						$fdisplayh(file, i[DMA_SIZE-1:0], "\t", dmData[i]);
					end
					$fclose(file);
 `endif
				end
			end
		end

endmodule

module memory_ext_1 #(parameter 
           `ifdef IGNORE
                  DM_LOCATE="ext1memload.mem",
           `endif
                  DMA_SIZE=3, DMD_SIZE=4)
			(
				input wire clk,
				input wire ps_dm_cslt,    // Data Memory Chip Select
				//input wire[PMD_SIZE-1:0] pmDataIn, (future scope)
				input wire ps_dm_wrb,      // Data Memory Read/Write
				input wire[DMA_SIZE-1:0] dg_dm_add,   // Data Memory Address Bus
				input wire[DMD_SIZE-1:0] bc_dt,	      // Data Memory Data In
				output wire[DMD_SIZE-1:0] dm_bc_dt     // Data Memory Data Out
			);

		integer file, i;

 //------------------------------------------------------------------------------------------------------------------------
 //				DM reading and writing
 //------------------------------------------------------------------------------------------------------------------------
		
		reg [DMD_SIZE-1:0] dmData [(2**DMA_SIZE)-1:0];  //to store real data with adress discarded from text file
		reg [DMD_SIZE-1:0] dm [2*(2**DMA_SIZE)-1:0];	//with address

		reg dm_cslt;
		reg dm_wrb;
		reg [DMA_SIZE-1:0] dm_add;
		wire [DMD_SIZE-1:0] dmBypData;

 `ifdef IGNORE
	//----------------------------------------------------------------------------------------
		//Initially open and close to clear the DM file
	/*	initial
		begin
			file=$fopen(DM_LOCATE,"w");
			$fclose(file);
		end*/
	
	//Comment above initial block if you want to access DM data present in data memory before startup.
	//----------------------------------------------------------------------------------------


		//initially load DM data from DM file (required when DM contains data to be read before startup)
		initial
		begin
			$readmemh(DM_LOCATE,dm);
			for(i=0; i<(2*(2**DMA_SIZE)); i=i+2)
			begin
				dmData[i/2]=dm[i+1];    //here address is to be discarded. Hence we read two words at a time
			end
		end
 `endif

		//DM bypass
		//assign dmBypData = (dm_add==dg_dm_add) ? bc_dt : dmData[dg_dm_add];
		

		//DM writing
		always@(posedge clk)
		begin
			if(ps_dm_cslt)
			begin
				if(ps_dm_wrb)
				begin
					dmData[dg_dm_add][DMD_SIZE-1:0] <= bc_dt ;
 `ifdef IGNORE
					file=$fopen(DM_LOCATE);
					for(i=0; i<(2**DMA_SIZE); i=i+1)
					begin
						$fdisplayh(file, i[DMA_SIZE-1:0], "\t", dmData[i]);
					end
					$fclose(file);
 `endif
				end
			end
		end
		
		//control signal latching for reading purpose only ( Write to memory at execute+1 cycle)
		always@(posedge clk)
		begin
			dm_cslt <= ps_dm_cslt;
			dm_wrb  <= ps_dm_wrb;
			dm_add  <= dg_dm_add;
		end

		//DM reading
    
	/*	always@(posedge clk )
		begin
			if(dm_cslt)
			begin
				if(~dm_wrb)
				begin
          dm_bc_dt<=dmData[dm_add];
				end
			end
		end*/

    assign dm_bc_dt= (dm_cslt && ~dm_wrb)? dmData[dm_add] : 16'hz;

endmodule

module memory_ext_2 #(parameter 
           `ifdef IGNORE
                  DM_LOCATE="ext2memload.mem",
           `endif
                  DMA_SIZE=3, DMD_SIZE=4)
			(
				input wire clk,
				input wire ps_dm_cslt,    // Data Memory Chip Select
				//input wire[PMD_SIZE-1:0] pmDataIn, (future scope)
				input wire ps_dm_wrb,      // Data Memory Read/Write
				input wire[DMA_SIZE-1:0] dg_dm_add,   // Data Memory Address Bus
				input wire[DMD_SIZE-1:0] bc_dt,	      // Data Memory Data In
				output wire[DMD_SIZE-1:0] dm_bc_dt     // Data Memory Data Out
			);

		integer file, i;

 //------------------------------------------------------------------------------------------------------------------------
 //				DM reading and writing
 //------------------------------------------------------------------------------------------------------------------------
		
		reg [DMD_SIZE-1:0] dmData [(2**DMA_SIZE)-1:0];  //to store real data with adress discarded from text file
		reg [DMD_SIZE-1:0] dm [2*(2**DMA_SIZE)-1:0];	//with address

		reg dm_cslt,cslt;
		reg dm_wrb,wrb;
		reg [DMA_SIZE-1:0] dm_add,add;
		wire [DMD_SIZE-1:0] dmBypData;

 `ifdef IGNORE
	//----------------------------------------------------------------------------------------
		//Initially open and close to clear the DM file
	initial
		begin
			file=$fopen(DM_LOCATE,"w");
			$fclose(file);
		end
	
	//Comment above initial block if you want to access DM data present in data memory before startup.
	//----------------------------------------------------------------------------------------


		//initially load DM data from DM file (required when DM contains data to be read before startup)
		initial
		begin
			$readmemh(DM_LOCATE,dm);
			for(i=0; i<(2*(2**DMA_SIZE)); i=i+2)
			begin
				dmData[i/2]=dm[i+1];    //here address is to be discarded. Hence we read two words at a time
			end
		end
 `endif

		//DM bypass
		//assign dmBypData = (dm_add==dg_dm_add) ? bc_dt : dmData[dg_dm_add];
		

		//DM writing
		always@(posedge clk)
		begin
			if(ps_dm_cslt)
			begin
				if(ps_dm_wrb)
				begin
					dmData[dg_dm_add][DMD_SIZE-1:0] <= bc_dt ;
 `ifdef IGNORE
					file=$fopen(DM_LOCATE);
					for(i=0; i<(2**DMA_SIZE); i=i+1)
					begin
						$fdisplayh(file, i[DMA_SIZE-1:0], "\t", dmData[i]);
					end
					$fclose(file);
 `endif
				end
			end
		end
		
		//control signal latching for reading purpose only ( Write to memory at execute+2 cycle)
		always@(posedge clk)
		begin
    if(~ps_dm_wrb && ps_dm_cslt) begin
			dm_cslt <= ps_dm_cslt;
      cslt<=dm_cslt;

			dm_wrb  <= ps_dm_wrb;
      wrb<=dm_wrb;

			dm_add  <= dg_dm_add;
      add<=dm_add;
      end
		end

		//DM reading
	/*	always@(posedge clk )
		begin
			if(cslt)
			begin
				if(~wrb)
				begin
          dm_bc_dt<=dmData[add];
				end
			end
		end*/
    
    assign dm_bc_dt = (cslt && ~wrb) ? dmData[add] : 16'hz;
endmodule

module DMAC(IOA,EPA,EPD_OUT,IOD_OUT,EPD_IN,IOD_IN,clk,rst,wrb,stall_int,stall_ext);

 input wire clk,rst,stall_int,stall_ext;
 input wire[15:0] IOD_IN,EPD_IN;  
 output wire wrb;
 //output reg int_en,ext_en;
 output wire[15:0] EPD_OUT,IOD_OUT;
 output reg[15:0] IOA;
 output reg[15:0] EPA;

 wire empty,full;
 wire[15:0] buff_in,buff_out;
 reg[15:0] IOA_L1;
 reg[15:0] EPA_L1,EPA_L2;
 
 reg wr_en,rd_en,wr_en_l1,wr_en_l2,wr_en_l3,wr_en_l4,rd_en_l1,rd_en_l2,rd_en_l3;
 
 reg[2:0] DMAC=3'b001; // [Mem pipeline,TRANSFER,DMA ENABLE]

 //=================================================================================
 // TRANSFER=0 >> int to ext || TRANSFER=1 >> ext to int
 // Mem pipeline = 0 >> n+2 cycle || mem pipeline = 1 >> n+1 cycle
 //==================================================================================

 reg[15:0] II0=16'h0;
 reg[15:0] IM0=16'h1;
 reg[15:0] C0=16'h8;
 
 reg[15:0] EI0=16'h10;
 reg[15:0] EM0=16'h1;
 reg[15:0] EC0=16'h8;

 //assign en = DMAC[0];
 assign wrb = DMAC[1];

 FifoBuffer Buffer(buff_out,empty,full,buff_in,wr_en,rd_en,clk,rst);

 //------------------ fifo muxing and demuxing------------------------------------
 assign buff_in =(DMAC[1]==0)? IOD_IN : EPD_IN ;

 assign EPD_OUT =(DMAC[1]==0)? buff_out : 16'hz;
 assign IOD_OUT =(DMAC[1]==1)? buff_out : 16'hz;
 
 /*always@(*)
 begin
    if(DMAC[1]==0)
      EPD_OUT=buff_out;
    else
      IOD_OUT=buff_out;
 end*/
 //-------------------------------------------------------------------------------

 /* internal address generator - stage 1*/
 always@(posedge clk)
  begin
       if(DMAC[0]==1) 
        begin
            if(DMAC[1]==0)  // internal memory reading
                begin
                    if( C0!=0 && !full && !stall_int)
                      begin
                      IOA_L1<=II0;
                      II0=II0+IM0;
                      C0=C0-1; 
                      end
                    else
                      begin
                      IOA_L1<=IOA_L1;
                      II0=II0;
                      C0=C0; 
                      end
                end
            else        // internal memory writing
                begin
                    if( C0!=0 && !empty && !stall_int)
                      begin
                      IOA_L1<=II0;
                      II0=II0+IM0;
                      C0=C0-1; 
                      end
                    else
                      begin
                      IOA_L1<=IOA_L1;
                      II0=II0;
                      C0=C0; 
                      end
                end
        end        
  end

 /* Internal address latching stage-2*/ 
 always@(posedge clk)
  begin
      if(DMAC[0]==1)
       begin
            if(DMAC[1]==0)       
              begin
                if(!full && !stall_int)
                  IOA<=IOA_L1;
                else
                  IOA<=IOA; 
              end
            else                 
              begin
                if(!empty && !stall_int)
                  IOA<=IOA_L1;
                else
                  IOA<=IOA; 
              end
        end      
  end 

 /* external address generator - stage 1 */
 always@(posedge clk)
  begin
      if(DMAC[0]==1)
       begin
          if(DMAC[1]==0)           //external memory write
            begin
                if(EC0!=0 && !stall_ext && !empty) 
                  begin
                      EPA_L1<=EI0;
                      EI0=EI0+EM0;
                      EC0=EC0-1;   
                    end
                else                    
                  begin
                      EPA_L1<=EPA_L1;
                      EI0<=EI0;
                      EC0<=EC0;   
                  end
            end
          else                    //external memory read
            begin
                if(EC0!=0 && !stall_ext && !full) 
                  begin
                      EPA_L1<=EI0;
                      EI0=EI0+EM0;
                      EC0=EC0-1;   
                  end
                else
                  begin
                      EPA_L1<=EPA_L1;
                      EI0<=EI0;
                      EC0<=EC0;   
                  end
            end
        end    
  end

 /*External address latching stage-2*/ 
 always@(posedge clk)
  begin
      if(DMAC[0]==1)
        begin
            if(DMAC[1]==0)
            begin
                if(!stall_ext && !empty)
                    EPA<=EPA_L1;  
                else
                    EPA<=EPA;
              end
            else
              begin
                  if(!stall_ext && !full)
                   begin
                      if(DMAC[2]==0)
                        EPA<=EPA_L1;
                      else
                        begin 
                        EPA_L2<=EPA_L1;
                        EPA<=EPA_L2;
                        end  
                   end 
                  else
                    EPA<=EPA;
              end
        end
  end

 /*Fifo read and write controll*/
 
 always@(stall_int,stall_ext,empty,full,rst)
  begin
    if(DMAC[0]==1) 
     begin
          if(rst)
          begin
              wr_en_l1=1'b0;
              rd_en_l1=1'b0;
          end
          
          else if( (stall_ext && DMAC[1]==0) || (stall_int && DMAC[1]==1) )        
            begin
                rd_en_l1=1'b0;
                if(empty) 
                  wr_en_l1=1'b1; 
                else if(full)
                  wr_en_l1=1'b0; 
                else
                  wr_en_l1=1'b1;
            end

          else if( (stall_int && DMAC[1]==0) || (stall_ext && DMAC[1]==1) )  
            begin
                wr_en_l1=1'b0;
                if(empty) 
                  rd_en_l1=1'b0;
                else if(full)
                  rd_en_l1=1'b1; 
                else
                  rd_en_l1=1'b1;
            end

          else if(stall_ext && stall_int)
            begin
                wr_en_l1=1'b0;
                rd_en_l1=1'b0;
            end

          else
            begin
                if(empty) 
                  begin
                    wr_en_l1=1'b1;
                    rd_en_l1=1'b0;
                  end
                else if(full)
                  begin
                    wr_en_l1=1'b0;
                    rd_en_l1=1'b1;
                  end
                else
                  begin
                    wr_en_l1=1'b1;
                    rd_en_l1=1'b1; 
                  end
            end 
     end          
   end



   //======================= internal to external =============================
   //           internal read n cycle and external write n cycle

   always@(posedge clk)  
    begin
     if(DMAC[1]==0)
      begin
          wr_en_l2<=wr_en_l1;
          wr_en   <=wr_en_l2;

          rd_en<=rd_en_l1;
      end    
    end

  //======================= external to internal ===============================
  //          external read n+1 cycle and internal write n+1 cycle
  
  always@(posedge clk)  
   begin
      if(DMAC[1]==1)
      begin
          wr_en_l2<=wr_en_l1;
          wr_en_l3<=wr_en_l2;
          wr_en_l4<=wr_en_l3;
          wr_en   <=wr_en_l4;

          rd_en_l2<=rd_en_l1;
          rd_en<=rd_en_l2;
      end   
   end


  /*always@(stall,empty,full,rst)
  begin
   if(rst) begin
     wr_en=1'b0;
     rd_en=1'b0;
   end
  
   // =================================internal_read & external_write========================================================
   if(DMAC[1]==0)  
    begin
        if(stall)   // external memory stalled
         begin
              rd_en=1'b0;
              if(empty) 
                wr_en=1'b1; 
              else if(full)
                wr_en=1'b0; 
              else
                wr_en=1'b1;
          end
        else
         begin
              if(empty) 
               begin
                  wr_en=1'b1;
                  rd_en=1'b0;
                end
              else if(full)
               begin
                  wr_en=1'b0;
                  rd_en=1'b1;
                end
              else
                begin
                  wr_en=1'b1;
                  rd_en=1'b1; 
                end
          end    
    end
    //======================== external_read & internal_write========================================
   else                     
    begin
        if(stall)
         begin
             wr_en=1'b0;
             if(empty) 
                rd_en=1'b0;
             else if(full)
                rd_en=1'b1; 
             else
                rd_en=1'b1;
         end

        else
          begin
              if(empty) 
                begin
                  wr_en=1'b1;
                  rd_en=1'b0;
                end
              else if(full)
                begin
                  wr_en=1'b0;
                  rd_en=1'b1;
                end
              else
                begin
                  wr_en=1'b1;
                  rd_en=1'b1; 
                end
          end
    end
  end*/

endmodule


/*module dmaTest();
 //inputs
 reg[15:0] IOD_IN,EPD_IN;
 reg clk,rst,stall_ext,stall_int;
 reg int_en,ext_en;
 // Outputs
 wire[16:0] IOA,IOA_L1;
 wire[31:0] EPA,EPA_L1,EPA_L2;
 wire[15:0] EPD_OUT,IOD_OUT;
 wire empty,full,wr_en,rd_en,wr_en_l1,wr_en_l2,wr_en_l3,wr_en_l4,rd_en_l1,rd_en_l2,rd_en_l3;
 reg[31:0] EPA_x;
 // Instantiate the Unit Under Test (UUT) 
 DMAC uut(IOA,IOA_L1,EPA,EPA_L1,EPA_L2,EPD_OUT,IOD_OUT,EPD_IN,IOD_IN,clk,rst,stall_int,stall_ext,empty,full,wr_en,rd_en,wr_en_l1,wr_en_l2,wr_en_l3,wr_en_l4,rd_en_l1,rd_en_l2,rd_en_l3);
  initial 
  begin
   clk = 1'b0;
   forever #5 clk=~clk;
  end
  
 initial 
  begin
      rst = 1'b0;
   #2 rst = 1'b1;
   #1 rst = 1'b0;
  end

  initial 
  begin
       stall_ext = 1'b0;
       stall_int=0;
   /*#80 stall = 1'b1;
   #30 stall = 1'b0;
   #30 stall = 1'b1;
   #30 stall = 1'b0;
  end
    
 always@(IOA)
 begin
  case(IOA)
     17'h0:  IOD_IN=16'h10;
     17'h1:  IOD_IN=16'h20;
     17'h2:  IOD_IN=16'h30;
     17'h3:  IOD_IN=16'h40;
     17'h4:  IOD_IN=16'h50;
     17'h5:  IOD_IN=16'h60;
     17'h6:  IOD_IN=16'h70;
     17'h7:  IOD_IN=16'h80;
     17'h8:  IOD_IN=16'h90;
     17'h9:  IOD_IN=16'h100;
     17'hA:  IOD_IN=16'h110;
     17'hB:  IOD_IN=16'h120;
     17'hC:  IOD_IN=16'h130;
     17'hD:  IOD_IN=16'h140;
     17'hE:  IOD_IN=16'h150;
     17'hF:  IOD_IN=16'h160;
   default:  IOD_IN=16'bx;
  endcase
 end
 
 always@(posedge clk)
  begin
    EPA_x<=EPA;
  end

 /*always@(posedge clk)
  begin
  if(!stall_ext)
   begin
    case(EPA_x)
      32'h0:  EPD_IN<=16'h10;
      32'h1:  EPD_IN<=16'h20;
      32'h2:  EPD_IN<=16'h30;
      32'h3:  EPD_IN<=16'h40;
      32'h4:  EPD_IN<=16'h50;
      32'h5:  EPD_IN<=16'h60;
      32'h6:  EPD_IN<=16'h70;
      32'h7:  EPD_IN<=16'h80;
      32'h8:  EPD_IN<=16'h90;
      32'h9:  EPD_IN<=16'h100;
      32'hA:  EPD_IN<=16'h110;
      32'hB:  EPD_IN<=16'h120;
      32'hC:  EPD_IN<=16'h130;
      32'hD:  EPD_IN<=16'h140;
      32'hE:  EPD_IN<=16'h150;
      32'hF:  EPD_IN<=16'h160;
    default:  EPD_IN<=16'bx;
    endcase
   end 
  else
    EPD_IN<=EPD_IN;
 end

 always@(posedge clk)
  begin
  if(!stall_ext)
   begin
    case(EPA)
      32'h0:  EPD_IN<=16'h10;
      32'h1:  EPD_IN<=16'h20;
      32'h2:  EPD_IN<=16'h30;
      32'h3:  EPD_IN<=16'h40;
      32'h4:  EPD_IN<=16'h50;
      32'h5:  EPD_IN<=16'h60;
      32'h6:  EPD_IN<=16'h70;
      32'h7:  EPD_IN<=16'h80;
      32'h8:  EPD_IN<=16'h90;
      32'h9:  EPD_IN<=16'h100;
      32'hA:  EPD_IN<=16'h110;
      32'hB:  EPD_IN<=16'h120;
      32'hC:  EPD_IN<=16'h130;
      32'hD:  EPD_IN<=16'h140;
      32'hE:  EPD_IN<=16'h150;
      32'hF:  EPD_IN<=16'h160;
    default:  EPD_IN<=16'bx;
    endcase
   end 
  else
    EPD_IN<=EPD_IN;
 end
endmodule*/

module dmaTest();
 //inputs
 
 reg clk,rst,stall_ext,stall_int;
 reg ps_dm_cslt;

 // Outputs
 wire[15:0] IOA;
 wire[15:0] EPA;
 wire[15:0] EPD_OUT,IOD_OUT;
 wire[15:0] IOD_IN,EPD_IN;
 wire wrb;

 // Instantiate the Unit Under Test (UUT) 
 DMAC uut(IOA,EPA,EPD_OUT,IOD_OUT,EPD_IN,IOD_IN,clk,rst,wrb,stall_int,stall_ext);

 memory_int #(.DMA_SIZE(16), .DMD_SIZE(16))
		testMemint(
					clk,
					ps_dm_cslt,
				  wrb,
					IOA,
					IOD_OUT,
					IOD_IN
				);
 /*memory_ext_1 #(.DMA_SIZE(16), .DMD_SIZE(16))
		testMemext1	(
					clk,
					ps_dm_cslt,
				  ~wrb,
					EPA,
					EPD_OUT,
					EPD_IN
				);*/
 memory_ext_2 #(.DMA_SIZE(16), .DMD_SIZE(16))
    testMemext2	(
          clk,
          ps_dm_cslt,
          ~wrb,
          EPA,
          EPD_OUT,
          EPD_IN
        );     

  initial 
  begin
   clk = 1'b1;
   forever #5 clk=~clk;
  end
  
 initial 
  begin
      rst = 1'b0;
   #2 rst = 1'b1;
   #1 rst = 1'b0;
  end

  initial 
  begin
       stall_ext = 1'b0;
       stall_int=0;
       #12 ps_dm_cslt=1;
   #30 stall_int = 1'b1;
   #30 stall_int = 1'b0;
   #40 stall_int = 1'b1;
   #30 stall_int = 1'b0;
  end
endmodule
