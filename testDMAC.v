module testDMA();
 //inputs

 reg clk,rst,stall_ext,stall_int,reg_access=0;

 // Outputs
 wire[15:0] NPA,SPA;
 wire[15:0] NPD_OUT,SPD_OUT;
 wire[15:0] NPD_IN,SPD_IN;
 wire wr_rd_np,wr_rd_sp,np_en,sp_en;

 // Instantiate the Unit Under Test (UUT) 

 DMAC #(.ADR_SIZE(16), .DATA_SIZE(16))
      tstDMA(
           clk,
           rst,
           stall_int,
           stall_ext,
           reg_access,
           NPD_IN,
           SPD_IN,
           wr_rd_np,
           wr_rd_sp,
           np_en,
           sp_en,
           NPA,
           SPA,
           NPD_OUT,
           SPD_OUT
        );

 memory_int #(.DMA_SIZE(16), .DMD_SIZE(16))
		testMemint(
					clk,
					np_en,
				  wr_rd_np,
					NPA,
					NPD_OUT,
					NPD_IN
				);
/* memory_ext_1 #(.DMA_SIZE(16), .DMD_SIZE(16))
		testMemext1	(
					clk,
					sp_en,
				  wr_rd_sp,
					SPA,
					SPD_OUT,
					SPD_IN
				);*/
memory_ext_2 #(.DMA_SIZE(16), .DMD_SIZE(16))
    testMemext2	(
          clk,
          sp_en,
          wr_rd_sp,
          SPA,
          SPD_OUT,
          SPD_IN
        );

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
       stall_int = 1'b0;
       stall_ext=0;
      #46 stall_ext = 1'b0;
      #30 stall_ext = 1'b0;
      #40 stall_ext = 1'b0;
      #30 stall_ext = 1'b0;
  end
endmodule