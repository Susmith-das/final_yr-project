module testDMA();
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
 DMAC uut(IOA,IOD_IN,IOD_OUT,EPA,EPD_IN,EPD_OUT,clk,rst,wrb,stall_int,stall_ext);

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
       #8 ps_dm_cslt=1;
   #32 stall_int = 1'b1;
   #30 stall_int = 1'b0;
   #40 stall_int = 1'b1;
   #30 stall_int = 1'b0;
  end
endmodule