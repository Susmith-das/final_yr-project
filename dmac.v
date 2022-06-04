module DMAC #(parameter ADR_SIZE=16, DATA_SIZE=16)
        (
          input wire  clk,
          input wire  rst,
          input wire  r_b_NP,
          input wire  r_b_SP,
          input wire  reg_access,
          
          input wire[DATA_SIZE-1:0] NPD_IN,
          input wire[DATA_SIZE-1:0] SPD_IN,

          output reg  wr_rd_NP,
          output reg  wr_rd_SP,
          output reg  NP_en,
          output reg  SP_en,

          output reg[ADR_SIZE-1:0] NPA,
          output reg[ADR_SIZE-1:0] SPA,
          
          output reg[DATA_SIZE-1:0] NPD_OUT,
          output reg[DATA_SIZE-1:0] SPD_OUT
        );
 
 reg[DATA_SIZE-1:0] buff_in;
 wire[DATA_SIZE-1:0] buff_out;

 wire empty,full;
 reg  wr_en,rd_en;

 reg[ADR_SIZE-1:0] NPA_L1;
 reg[ADR_SIZE-1:0] SPA_L1,SPA_L2;
 
 /*=================================================================================
  DMAC[reserved|scatter/gather|mode[1]|mode[0]|DIR[1]|DIR[0]|Mem pipeline|DMA ENABLE]
  
        DIR
   00 - int to int
   01 - int to ext
   10 - ext to int
   11 - ext to ext

    Mem pipeline
   0 >> n+2 cycle 
   1 >> n+1 cycle

        mode
   00 - normal mode
   01 - chaining
   10 - scatter gather
   11 - resrved     
 =================================================================================*/
 reg[ADR_SIZE-1:0] DMAC;//= { {9{1'b0}} , 1'b1 , 2'b10 , 2'b01 , 1'b0 , 1'b1 };
 reg[ADR_SIZE-1:0] SI0;//=16'h0011;   // source index address
 reg[ADR_SIZE-1:0] SM0;//=16'h1;      // source address modifier
 reg[ADR_SIZE-1:0] SC0;//=16'hA;      // source transfer counter 
                   
 reg[ADR_SIZE-1:0] DI0;//=16'h0;      // destination index address
 reg[ADR_SIZE-1:0] DM0;//=16'h1;      // destination address modifier
 reg[ADR_SIZE-1:0] DC0;//=16'hA;      // destination transfer counter

 reg[ADR_SIZE-1:0] SGC;//=16'hA;      // scatter gather counter
 reg[ADR_SIZE-1:0] SGR;//=16'h0021;   // scatter pointer

 reg[ADR_SIZE-1:0] CP;// =16'h2;      // chain pointer
 reg[ADR_SIZE-1:0] WR;// =16'h0;      // working register
 reg[ADR_SIZE-1:0] GP;// =16'h0;      // general purpose register

/* reg[ADR_SIZE-1:0] NC0_l1=0,NC0_l2=0,NC0_l3=0;
 reg[ADR_SIZE-1:0] SC0_l1=0,SC0_l2=0,SC0_l3=0,SC0_l4=0,SC0_l5=0,SC0_l6=0;*/

 reg[ADR_SIZE-1:0] NC0_l1,NC0_l2,NC0_l3;
 reg[ADR_SIZE-1:0] SC0_l1,SC0_l2,SC0_l3,SC0_l4,SC0_l5,SC0_l6;
 
 // memory mapped register access
 always@(posedge clk)
 begin
   if(reg_access==1'b1)
   begin
    case(NPA)
        16'hFFF0: DMAC <= NPD_IN;
        16'hFFF1: SI0  <= NPD_IN;
        16'hFFF2: SM0  <= NPD_IN;
        16'hFFF3: SC0  <= NPD_IN;
        16'hFFF4: DI0  <= NPD_IN;
        16'hFFF5: DM0  <= NPD_IN;
        16'hFFF6: DC0  <= NPD_IN;
        16'hFFF7: SGC  <= NPD_IN;
        16'hFFF8: SGR  <= NPD_IN;
        16'hFFF9: CP   <= NPD_IN;
        16'hFFFA: WR   <= NPD_IN;
        16'hFFFB: GP   <= NPD_IN;
        default:  GP<=GP ;
     endcase
  end
 end

 always@(posedge rst)
  begin
    wr_en   <=1'b0;
    rd_en   <=1'b0;
    wr_rd_NP<=1'b0;
    wr_rd_SP<=1'b0;
    NP_en   <=1'b0;
    SP_en   <=1'b0;
  end

 always@(*)
 begin
   if(DMAC[5:4]==2'b10)
    begin
      if(DMAC[6]==1'b0)
        DMAC[3:2] = 2'b01;
      else
        DMAC[3:2] = 2'b10;  
    end  
   else
    begin
      DMAC[3] = (SI0[15:12]==4'b1111)? 1'b0:1'b1;
      DMAC[2] = (DI0[15:12]==4'b1111)? 1'b0:1'b1; 
    end    
 end

 // port muliplexing and demultiplexing

 always@(*)  
 begin
   if(DMAC[3:2]==2'b00)       // internal to internal
    begin
       buff_in =NPD_IN;
       NPD_OUT =buff_out;
    end
   else if(DMAC[3:2]==2'b01)  // internal to external
    begin
       buff_in =NPD_IN;
       SPD_OUT =buff_out;
    end
   else if(DMAC[3:2]==2'b10)  // external to internal
    begin
       buff_in = SPD_IN;
       NPD_OUT = buff_out;
    end
   else                       // external to external
    begin
       buff_in =SPD_IN;
       SPD_OUT =buff_out;
    end  
 end
 
 //------------------ fifo muxing and demuxing------------------------------------
 
 /*assign buff_in= (DMAC[3]==1'b0)? NPD_IN : SPD_IN;

 always@(*)
 begin
   if(DMAC[2]==1'b0)
      NPD_OUT=buff_out;
   else
      SPD_OUT=buff_out; 
 end*/

 //--------------------------------------------------FIFO---------------------------------------------------

 FifoBuffer F1(buff_out,empty,full,buff_in,wr_en,rd_en,clk,rst);

//--------------------------------------------internal to internal--------------------------------------
 
 reg[2:0] state;
 parameter s0=3'b000 ,s1=3'b001 ,s2=3'b010 ,s3=3'b011 ,s4=3'b100 ;

 always@ (posedge clk or posedge rst) 
 begin
  if(rst)
   begin
     state<=s0;
   end 
  else if(DMAC[0]==1'b1 && DMAC[3:2]==2'b00 && DMAC[5]=1'b0)     
   begin
      case(state)
          s0: begin
                wr_en   <=1'b0;
                rd_en   <=1'b0;
                wr_rd_NP<=1'b0;
                wr_rd_SP<=1'b0;
                NP_en   <=1'b1;
                SP_en   <=1'b0;

                NPA<=SI0;
                SI0<=SI0+SM0;
                SC0<=SC0-1;

                if(SC0==1'b0 && DC0==1'b0)
                  DMAC[0]<= 1'b0;
                else
                  state<=s1;  
              end 
          s1: begin
                wr_en   <=1'b1;
                rd_en   <=1'b1;
                wr_rd_NP<=1'b1;
                wr_rd_SP<=1'b0;
                NP_en   <=1'b1;
                SP_en   <=1'b0;

                NPA<=DI0;
                DI0<=DI0+SM0;
                DC0<=DC0-1;

                state<=s2;
              end
          s2: begin
                NPA<=DI0;
                DI0<=DI0+DM0;
                DC0<=DC0-1;
                wr_rd_NP<=1'b1;
                wr_en<=1'b0;
                rd_en<=1'b1;
                state<=s3;
              end
          s3: begin
                wr_en<=1'b0;
                rd_en<=1'b0;
                wr_rd_NP<=1'b0;
                state<=s0;
              end
          default: begin
                wr_en<=1'b0;
                rd_en<=1'b0;
                wr_rd_NP<=1'b0;
              end
      endcase
   end

   else if(DMAC[0]==1'b1 && DMAC[3:2]==2'b11)
   begin
      case(state)
        s0: state<=(SC0!=1'b0 && DC0!=1'b0) ? s1: s0;
        s1: state<=s2;
        s2: state<=s0;
        default: state<=s0;  
      endcase
   end
 end

 always@ (posedge clk)
 begin
   if(DMAC[3:2]==2'b00)
   begin
      
   end

   else if(DMAC[3:2]==2'b11)
   begin
       case(state)
          s0: begin
                SPA<=SI0;
                SI0<=SI0+SM0;
                SC0<=SC0-1;
                wr_rd_SP<=1'b0;
              end 
          s1: begin
                wr_en<=1;
                rd_en<=1;
                wr_rd_SP<=1;
              end
          s2: begin
                SPA<=DI0;
                DI0<=DI0+DM0;
                DC0<=DC0-1;
                wr_rd_SP<=1'b0;
                wr_en<=1'b0;
                rd_en<=1'b0;
              end
          default: begin
                wr_rd_SP<=1'b0;
                wr_en<=1'b0;
                rd_en<=1'b0;
              end
      endcase
   end
 end

//--------------------------------------------------Chained-----------------------------------------------------------------------------
 parameter Sch0= 4'b0000,
           Sch1= 4'b0001,
           Sch2= 4'b0010,
           Sch3= 4'b0011,
           Sch4= 4'b0100,
           Sch5= 4'b0101,
           Sch6= 4'b0110,
           Sch7= 4'b0111,
           Sch8= 4'b1000,
           Sch9= 4'b1001,
           Sch10=4'b1010,
           Sch11=4'b1011;

 reg[3:0] SchState;
 
 always @(posedge clk or posedge rst) 
   begin
       if(rst)
          begin 
            SchState<=Sch11;
            //NC0 <=0;
            //SC0 <=0;
          end 
       else if(DMAC[5:4] == 2'b01 && CP != 16'h0 )
          begin
            case (SchState)
              Sch0: begin
                    DMAC[0] <= 1'b0;
                    WR      <= CP;
                    NP_en   <= 1'b0;
                    SP_en   <= 1'b0;
                    wr_rd_NP<= 1'b0;
                    wr_rd_SP<= 1'b0;
                    wr_en   <= 1'b0;
                    rd_en   <= 1'b0;
                    SchState <= Sch1;
                  end
              Sch1:begin
                    NPA <= WR;
                    WR  <= WR + 1;
                    NP_en <= 1;
                    SchState <= Sch2;
                  end
              Sch2:begin
                    NPA <= WR;
                    WR  <= WR + 1;
                    SchState <= Sch3;
                  end
              Sch3: begin
                    NPA <= WR;
                    WR  <= WR + 1;
                    SI0 <= NPD_IN;
                    SchState <= Sch4;
                  end
              Sch4: begin
                    NPA <= WR; 
                    WR  <= WR + 1;
                    SM0 <= NPD_IN;
                    SchState <= Sch5;
                  end
              Sch5: begin
                    NPA <= WR;
                    WR  <= WR + 1;
                    SC0 <= NPD_IN;
                    SchState <= Sch6;
                  end
              Sch6: begin
                    NPA <= WR;
                    WR  <= WR + 1;
                    CP  <= NPD_IN;
                    SchState <= Sch7;
                  end
              Sch7: begin
                    NPA <= WR;
                    WR  <= WR + 1;
                    GP  <= NPD_IN;
                    SchState <= Sch8;
                  end
              Sch8: begin
                    NPA <= WR;
                    DI0 <= NPD_IN;
                    SchState <= Sch9;
                  end
              Sch9: begin
                    DM0 <= NPD_IN;
                    NP_en<=1'b0;
                    SchState <= Sch10;
                  end
              Sch10:begin  
                    DC0  <= NPD_IN;
                    SchState <= Sch11;

                    if(DMAC[5:2]==4'b0100)
                      wr_rd_SP<=1'b0;
                    else if(DMAC[5:2]==4'b0101)
                    begin
                      wr_rd_NP<=1'b0;
                      wr_rd_SP<=1'b0;
                    end
                    else if(DMAC[5:2]==4'b0110)
                    begin
                      wr_rd_NP<=1'b1;
                      wr_rd_SP<=1'b0;
                    end
                    else if(DMAC[5:2]==4'b0111)
                      wr_rd_NP<=1'b0;
                    end
              Sch11:begin
                      DMAC[0] <=(CP==16'h0)? 1'b0:1'b1;
                      SchState<= ((SC0==1'b0 && DC0 == 1'b0) && CP != 16'h0) ? Sch0 : Sch11;
                    end     
              default: SchState <= Sch11; 
            endcase 
          end
    end     
//-----------------------------------------------Scatter-Gather---------------------------------------------------------------------

 reg[2:0] Scstate;
 reg[2:0] Sgstate;
 
 parameter Sc0= 3'b000,
           Sc1= 3'b001,
           Sc2= 3'b010,
           Sc3= 3'b011,
           Sc4= 3'b100,
           Sc5= 3'b101; 

 parameter Sg0= 3'b000, 
           Sg1= 3'b001, 
           Sg2= 3'b010, 
           Sg3= 3'b011, 
           Sg4= 3'b100, 
           Sg5= 3'b101, 
           Sg6= 3'b110,
           Sg7= 3'b111;

 always @(posedge clk or posedge rst)
   begin
       if(rst)
          begin 
            Scstate<=Sc0;
            Sgstate<=Sg0;
          end 
       else if(DMAC[5:4] == 2'b10 && DMAC[6] == 1'b0 && DMAC[0]==1'b1)
          begin
            case (Scstate)
            Sc0: begin
                  wr_en <=0;
                  rd_en <=0;
                  NP_en <=0;
                  SP_en <=0; 
                  wr_rd_NP<=0;
                  wr_rd_SP<=0;
                  if(SC0 ==0 && SGC == 0)
                    DMAC[0] <= 1'b0;
                  else  
                    Scstate <= Sc1;
                 end 
            Sc1: begin
                  NP_en <=1;
                  NPA <= SI0;
                  SI0 <= SI0 + 1;
                  SC0 <= SC0 - 1;
                  Scstate <= Sc2;
                 end
            Sc2: begin
                  wr_en <= 1;
                  NP_en  <=0;
                  Scstate <= Sc3;
                 end 
            Sc3: begin 
                  NP_en  <=1;
                  wr_en <= 0;
                  NPA <= SGR;
                  SGR <= SGR + 1;
                  SGC <= SGC - 1;
                  Scstate <= Sc4;
                 end
            Sc4: begin
                  NP_en  <=0;
                  rd_en <= 1;
                  Scstate <= Sc5;
                 end
            Sc5:begin
                 SP_en <=1;
                 rd_en <= 0;
                 wr_rd_SP<=1;
                 SPA<=NPD_IN;
                 Scstate <= Sc0;
                end   
            default: Scstate <= Sc0;
           endcase
         end
       else if(DMAC[5:4] == 2'b10 && DMAC[6] == 1 && DMAC[0]==1)
        begin 
          case (Sgstate)
            Sg0: begin
                  wr_en <=0;
                  rd_en <=0;
                  NP_en <=0;
                  SP_en <=0;
                  wr_rd_NP<=0;
                  wr_rd_NP<=0;
                  DMAC[0] <= (SC0 == 0 && SGC == 0) ? 0 : 1;
                  Sgstate <= (SC0==0 && SGC == 0) ? Sg0 : Sg1;
                 end 
            Sg1: begin
                  NP_en <=1;
                  NPA <= SGR;
                  SGR <= SGR + 1;
                  SGC <= SGC - 1;
                  Sgstate <= Sg2;
                 end
            Sg2:begin
                  NP_en <=0;
                  Sgstate <= Sg3;
                end
            Sg3: begin
                  SP_en <=1;
                  SPA <= NPD_IN;
                  Sgstate <= Sg4; 
                 end
            Sg4: begin
                  SP_en <=0;
                  Sgstate <= (DMAC[1]==0)? Sg5:Sg6;
                 end
            Sg5: begin
                  Sgstate <= Sg6;
                 end     
            Sg6: begin
                  wr_en <=1;
                  Sgstate <= Sg7;
                 end 
            Sg7: begin
                  wr_en <=0;
                  rd_en <=1;
                  NP_en <=1;
                  wr_rd_NP<=1;
                  NPA<=SI0;
                  SI0<=SI0+1;
                  SC0<=SC0-1;
                  Sgstate <= Sg0;
                 end            
            default: Sgstate <= Sg0;
          endcase  
        end
  end

//-----------------------------------------------Pipelined transfer-----------------------------------------------------------------
 
 always@(*)
 begin
    if(DMAC[5:2]==4'b0000)
      wr_rd_SP<=1'b0;
    else if(DMAC[5:2]==4'b0001)
    begin
      wr_rd_NP<=0;
      wr_rd_SP<=1;
    end
    else if(DMAC[5:2]==4'b0010)
    begin
      wr_rd_NP<=1;
      wr_rd_SP<=0;
    end
    else if(DMAC[5:2]==4'b0011)
      wr_rd_NP<=1'b0;
 end
 
 /* internal address generator - stage 1*/
 always@(posedge clk)
  begin
       if(DMAC[0]==1'b1 && DMAC[5]== 1'b0) 
        begin
            if(DMAC[3:2]==2'b01)  // internal memory reading
                begin
                    if( SC0!=0 && !full && !r_b_NP)
                      begin
                        NPA_L1<=SI0;
                        SI0<=SI0+SM0;
                        SC0<=SC0-1;
                      end
                end
            else if(DMAC[3:2]==2'b10)     // internal memory writing
                begin
                    if( DC0!=0 && !empty && !r_b_NP)
                      begin
                        NPA_L1<=DI0;
                        DI0<=DI0+DM0;
                        DC0<=DC0-1; 
                      end
                end
        end        
  end

 /* Internal address latching stage-2*/ 
 always@(posedge clk)
  begin
      if(DMAC[0]==1'b1 && DMAC[5]==1'b0)
       begin
            if(DMAC[3:2]==2'b01)         // internal reading
              begin
                if(NC0_l1!=0 && !full && !r_b_NP)
                  NPA<=NPA_L1;
              end
            else if(DMAC[3:2]==2'b10)                // internal writing
              begin
                if(NC0_l1!=0 && !empty && !r_b_NP)
                  NPA<=NPA_L1;
              end
        end      
  end 

 /* external address generator - stage 1 */
 always@(posedge clk)
  begin
      if(DMAC[0]==1'b1 && DMAC[5]==1'b0)
       begin
          if(DMAC[3:2]==2'b01)           //external memory write
            begin
                if(DC0!=0 && !empty && !r_b_SP) 
                  begin
                      SPA_L1<=DI0;
                      DI0<=DI0+DM0;
                      DC0<=DC0-1;   
                  end  
            end
          else if(DMAC[3:2]==2'b10)                   //external memory read
            begin
                if(SC0!=0 && !full && !r_b_SP) 
                  begin
                      SPA_L1<=SI0;
                      SI0<=SI0+SM0;
                      SC0<=SC0-1;   
                  end
            end
        end    
  end

 /*External address latching stage-2*/ 
 always@(posedge clk)
  begin
      if(DMAC[0]==1'b1 && DMAC[5]==1'b0)
        begin
            if(DMAC[3:2]==2'b01)  // ext writing
            begin
                if(SC0_l1!=0 && !empty && !r_b_SP)
                begin
                    SPA<=SPA_L1;
                end      
            end
            else if(DMAC[3:2]==2'b10)           // ext reading
              begin
                  if(SC0_l1!=0 && !full && !r_b_SP && DMAC[1]==0)
                    SPA<=SPA_L1;
                  
                  if((SC0_l1!=0 || SC0_l2!=0 )  && !full && !r_b_SP && DMAC[1]==1)
                    begin 
                    SPA_L2<=SPA_L1;
                    SPA<=SPA_L2;
                    end  
              end
        end
    end
 /* count keepers */
  always@(posedge clk)
  begin
       if(DMAC[0]==1'b1 && DMAC[5]==1'b0) 
        begin
            if(DMAC[3:2]==2'b01)
                begin
                    if(!full && !r_b_NP)      // internal reading
                    begin
                      NC0_l1<=SC0;
                      NC0_l2<=NC0_l1;
                      NC0_l3<=NC0_l2;
                    end 
                    if((!empty || SC0_l2==1) && !r_b_SP) // external writing
                    begin
                      SC0_l1<=DC0;
                      SC0_l2<=SC0_l1;
                    end 
                end
            else if(DMAC[3:2]==2'b10)        
                begin
                    if(!empty && !r_b_NP)   // internal writing
                      begin
                      NC0_l1<=DC0;
                      NC0_l2<=NC0_l1;
                      NC0_l3<=NC0_l2; 
                      end 
                    if(!full && !r_b_SP)    // external reading
                    begin
                        SC0_l1<=SC0;
                        SC0_l2<=SC0_l1;
                        SC0_l3<=SC0_l2;
                        SC0_l4<=SC0_l3;
                        SC0_l5<=SC0_l4;
                        SC0_l6<=SC0_l5; 
                    end    
                end
        end        
  end
 /*Fifo,port controll*/
  always@(negedge clk)
  begin
      if(DMAC[0]==1'b1 && DMAC[5]==1'b0)
       begin
            if(DMAC[3:2]==2'b01)                  
              begin
                if(NC0_l2!=0 && !full && !r_b_NP)
                  NP_en<=1;
                else
                  NP_en<=0;  

                if(SC0_l2!=0  && (!empty || SC0_l2==1) && !r_b_SP) 
                  SP_en<=1;   
                else
                  SP_en<=0;       
              
                if(NC0_l3!=0 && !full && !r_b_NP)   // internal reading
                  wr_en<=1;
                else
                  wr_en<=0; 
                
                if(SC0_l1!=0 && !empty && !r_b_SP)  // ext writing
                  rd_en<=1;   
                else
                  rd_en<=0;    
              end
               
            else if(DMAC[3:2]==2'b10)                
              begin
                if(NC0_l2!=0 && !empty && !r_b_NP)
                  NP_en<=1;
                else
                  NP_en<=0;  

                if(( (SC0_l2!=0 && DMAC[1]==0)||(SC0_l3!=0 && DMAC[1]==1) ) && !full && !r_b_SP) 
                  SP_en<=1;   
                else
                  SP_en<=0;       
              
                if(NC0_l2!=0 && !empty && !r_b_NP)   // internal writing
                  rd_en<=1;
                else
                  rd_en<=0; 
                
                if( ((SC0_l5!=0 && DMAC[1]==0) || (SC0_l6!=0 && DMAC[1]==1))  && !full && !r_b_SP)  // ext reading
                  wr_en<=1;   
                else
                  wr_en<=0;     
              end 
      end

  end

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