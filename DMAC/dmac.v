module DMAC(IOA,IOD_IN,IOD_OUT,EPA,EPD_IN,EPD_OUT,clk,rst,wrb,stall_int,stall_ext);

 input wire clk,rst,stall_int,stall_ext;
 input wire[15:0] IOD_IN,EPD_IN;  

 //output reg int_en,ext_en;
 output wire wrb;
 output wire[15:0] EPD_OUT,IOD_OUT;
 output reg[15:0] IOA;
 output reg[15:0] EPA;

 wire empty,full;
 wire[15:0] buff_in,buff_out;

 reg[15:0] IOA_L1;
 reg[15:0] EPA_L1,EPA_L2;
 reg wr_en,wr_en_l1,rd_en,rd_en_l1;
 
 reg[2:0] DMAC=3'b001; // [Mem pipeline,TRANSFER,DMA ENABLE]
 
 //=================================================================================
 // TRANSFER=0 >> int to ext || TRANSFER=1 >> ext to int
 // Mem pipeline = 0 >> n+2 cycle || mem pipeline = 1 >> n+1 cycle
 //==================================================================================

 reg[15:0] II0=16'h0;
 reg[15:0] IM0=16'h1;
 reg[15:0] C0=16'h8,C0_l1,C0_l2;
 
 reg[15:0] EI0=16'h10;
 reg[15:0] EM0=16'h1;
 reg[15:0] EC0=16'h8,EC0_l1,EC0_l2;

 //assign en = DMAC[0];
 assign wrb = DMAC[1];
 
 //------------------ fifo muxing and demuxing------------------------------------
 assign buff_in =(DMAC[1]==0)? IOD_IN : EPD_IN ;

 assign EPD_OUT =(DMAC[1]==0)? buff_out : 16'hz;
 assign IOD_OUT =(DMAC[1]==1)? buff_out : 16'hz;

 //assign wr_en = (DMAC[0]==1 && DMAC[1]==0)?  (~(C0_l1==0 || full || stall_int)? 1:0 ) : 0 ;
 //assign rd_en = (DMAC[0]==1 && DMAC[1]==0)?  (~(EC0_l1==0 || stall_ext || empty)? 1:0 ): 0 ;


 //-------------------------FIFO---------------------------------------------------

 FifoBuffer F1(buff_out,empty,full,buff_in,wr_en,rd_en,clk,rst);

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
                      II0<=II0+IM0;
                      C0<=C0-1;
                      end
                end
            else        // internal memory writing
                begin
                    if( C0!=0 && !empty && !stall_int)
                      begin
                      IOA_L1<=II0;
                      II0<=II0+IM0;
                      C0<=C0-1; 
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
                if(C0_l1!=0 && !full && !stall_int)
                begin
                  IOA<=IOA_L1;
                  wr_en_l1<=1;
                  wr_en<=wr_en_l1;
                end  
                else
                begin
                  IOA<=IOA;
                  wr_en_l1<=0;
                  wr_en<=wr_en_l1; 
                end 
              end
            else                 
              begin
                if(C0_l1!=0 && !empty && !stall_int)
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
                      EI0<=EI0+EM0;
                      EC0<=EC0-1;   
                    end
            end
          else                    //external memory read
            begin
                if(EC0!=0 && !stall_ext && !full) 
                  begin
                      EPA_L1<=EI0;
                      EI0<=EI0+EM0;
                      EC0<=EC0-1;   
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
                if(EC0_l1!=0 && !stall_ext && !empty)
                begin
                    EPA<=EPA_L1;
                    rd_en<=1;
                end      
                else
                begin
                    EPA<=EPA;
                    rd_en<=0;
                end
              end
            else
              begin
                  if(EC0_l1!=0 && !stall_ext && !full)
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

 always@(posedge clk)
  begin
       if(DMAC[0]==1) 
        begin
            if(DMAC[1]==0)
                begin
                    if(!full && !stall_int)
                    begin
                      C0_l1<=C0;
                      //C0_l1<=C0_l2;
                    end 
                    if(!empty && !stall_ext)
                      EC0_l1<=EC0;
                end
            else        
                begin
                    if(!empty && !stall_int)
                      begin
                      C0_l1<=C0;
                      //C0_l1<=C0_l2;
                      end 
                    if(!full && !stall_ext)
                    begin
                      if(DMAC[2]==0)
                        EC0_l1<=EC0;
                      else
                        begin
                        EC0_l2<=EC0;
                        EC0_l1<=EC0_l2;
                        end 
                    end    
                end
        end        
  end

 /*always@(stall_int,stall_ext,empty,full,rst)
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
     if(DMAC[1]==0 )
      begin
          wr_en_l2<=wr_en_l1;
          wr_en   <=wr_en_l2;
        //  wr_en<=wr_en_l1;

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
   end*/


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