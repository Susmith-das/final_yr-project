
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
 
 reg[3:0] DMAC=4'b10001; // [SG MODE,CHAINING,Mem pipeline,TRANSFER,DMA ENABLE]
 reg[0:1] SGM =2'b00;     // 4 bit combination 
 //==================================================================================
 // TRANSFER=0 >> int to ext || TRANSFER=1 >> ext to int
 // Mem pipeline = 0 >> n+2 cycle || mem pipeline = 1 >> n+1 cycle
 //==================================================================================

 reg[15:0] II0=16'h0011;
 reg[15:0] IM0=16'h1;
 reg[15:0] C0=16'h000A;
 reg[15:0] EI0=16'h10;
 reg[15:0] EM0=16'h1;
 reg[15:0] EC0=16'h0;
 reg[15:0] CP =16'h2;
 reg[15:0] WR =16'h0;
 reg[15:0] GP =16'h0;
 reg[15:0] SPR =16'h0021;
 reg[15:0] SPC =16'h000A;


 //assign en = DMAC[0];
 assign wrb = DMAC[1];
 
 reg[3:0] State;

  parameter S0= 4'b0000,S1= 4'b0001,S2= 4'b0010,S3= 4'b0011,S4= 4'b0100,S5= 4'b0101,S6= 4'b0110,S7= 4'b0111,S8= 4'b1000,S9= 4'b1001,S10=4'b1010;   
 //----------------------------------------------------------------CHAINING-----------------------------------------------------------------------------
 always @(posedge clk or posedge rst) 
   begin
       if(rst)
          begin 
            State<=S10;
            //C0 <=0;
            //EC0 <= 0;
            wr_en<=0;
            rd_en<=0;
          end 
       else if(DMAC[3] == 1 && CP != 16'h0 )
          begin
            case (State)
                S0: State <= S1;
                S1: State <= S2;
                S2: State <= S3;
                S3: State <= S4;
                S4: State <= S5;
                S5: State <= S6;
                S6: State <= S7;
                S7: State <= S8;
                S8: State <= S9;
                S9: State <= S10;
                S10:State <= ((C0==0 && EC0 == 0) && CP != 16'h0) ? S0 : S10;
                default: State <= S10;
            endcase
          end
   end     

 always @(State)
    begin
        case (State)
            S0: begin
                WR      <= CP;
                DMAC[0] <= 0;
                wr_en   <= 1;
                rd_en   <= 1;
                end
            S1: begin
                IOA <= WR;
                WR  <= WR + 1;
                end
            S2: begin
                IOA <= WR;
                II0 <= buff_in;
                WR  <= WR + 1;
                end
            S3: begin
                IOA <= WR;
                IM0 <= buff_in;
                WR  <= WR + 1;
                end
            S4: begin
                IOA <= WR;
                C0  <= buff_in;
                WR  <= WR + 1;
                end
            S5: begin
                IOA <= WR;
                CP  <= buff_in;
                WR  <= WR + 1;
                end
            S6: begin
                IOA <= WR;
                GP  <= buff_in;
                WR  <= WR + 1;
                end
            S7: begin
                IOA <= WR;
                EI0 <= buff_in;
                WR  <= WR + 1;
                end
            S8: begin
                IOA <= WR;
                EM0 <= buff_in;
                WR  <= WR + 1;
                end
            S9: begin
                EC0   <= buff_in;
                wr_en <= 0;
                rd_en <= 0;
                end
            S10:DMAC[0] <= 1; 
            default: State <= S10; 
        endcase 
    end
 //-------------------------------------------------------------------Scatter-Gather---------------------------------------------------------------------

 reg[0:2] Scstate;
 reg[0:2] Sgstate;

 parameter Sc0= 3'b000, Sc1= 3'b001, Sc2= 3'b010, Sc3= 3'b011, Sc4= 3'b100, Sc5= 3'b101, Sc6= 3'b110; 
 parameter Sg0= 3'b000, Sg1= 3'b001, Sg2= 3'b010, Sg3= 3'b011, Sg4= 3'b100, Sg5= 3'b101, Sg6= 3'b110;


 always @(posedge clk or posedge rst)
   begin
       if(rst)
          begin 
            Scstate<=Sc0;
            Sgstate<=Sg0;
            //C0 <=0;
            //SPC <= 0;
            wr_en<=0;
            rd_en<=0;
          end 
       else if(DMAC[4] == 1 && DMAC[1] == 0)
          begin
            case (Scstate)
                Sc0: Scstate <= (C0 ==0 && SGC == 0) ? Sc0 : Sc1;
                Sc1: Scstate <= Sc2;
                Sc2: Scstate <= Sc3;
                Sc3: Scstate <= Sc4;
                Sc4: Scstate <= Sc5;
                Sc5: Scstate <= Sc0;
                default: Scstate <= Sc0;
            endcase
         end
       else if(DMAC[4] == 1 && DMAC[1] == 1)
            begin 
              case (Sgstate)
                  Sg0: Sgstate <= (C0 ==0 && SGC == 0) ? Sg0 : Sg1;
                  Sg1: Sgstate <= Sg2;
                  Sg2: Sgstate <= Sg3;
                  Sg3: Sgstate <= Sg4;
                  Sg4: Sgstate <= Sg5;
                  Sg5: Sgstate <= Sg0;
                  default: Sgstate <= Sg0; 
              endcase
            end
  end
  always @(Scstate)
    begin
        case (Scstate)
            Sc0: DMAC[4] <= (C0 ==0 && SGC == 0) ? 0 : 1;
            Sc1: begin
                 IOA     <= II0;
                 II0     <= II0 + 1;
                 C0      <= C0 - 1;
                 wr_en   <= 1;
                 rd_en   <= 0;
                 end
            Sc2: wr_en <= 0;
            Sc3: begin 
                 IOA <= SPR;
                 SPR <= SPR + 1;
                 SPC <= SPC - 1;
                 end
            Sc4: begin
                 EPA   <= IOD_IN;
                 rd_en <= 1;
                 end
            Sc5: begin
                 wr_en <= 0;
                 rd_en <= 0;
                 end
            default: Scstate <= Sc0;
        endcase
    end 
   always @(Sgstate)
    begin
        case (Sgstate)
            Sg0: DMAC[4] <= (C0 == 0 && SPC == 0) ? 0 : 1;
            Sg1: begin
                 IOA     <= SPR;
                 SGR     <= SGR + 1;
                 SGC     <= SGC - 1;
                 end
            Sg2:begin
                EPA      <= IOD_IN;
                wr_en    <= 1;
                rd_en    <= 0;
                end
            Sg3: begin 
                 IOA     <= II0;
                 rd_en   <= 1;
                 end
            Sg4: begin
                 II0     <= II0 + 1;
                 C0      <= C0 - 1;
                 rd_en   <= 0;
                 wr_en   <= 0;
                 end
            default: Sgstate <= Sg0;
        endcase
    end 
//------------------------------------------------------------------------------------------------------------------------------------------------------ 

 