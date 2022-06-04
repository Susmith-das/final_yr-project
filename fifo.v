module FifoBuffer(buff_out,empty,full,buff_in,wr_en,rd_en,clk,rst);

  input wire clk,rst,rd_en,wr_en;
  input wire[15:0] buff_in;         // 16 bit data in bus
  
  output wire empty,full;            // flags
  output reg[15:0] buff_out;      //  FIFO out
   
  reg[2:0] rd_ptr=0 ,wr_ptr=0;  // location pointer
  reg[3:0] count=0;            //  current data count
  reg[15:0] buffer[7:0];      //   16 bit - 8 location

  assign empty = (count==0)? 1'b1:1'b0;
  assign full  = (count==8)? 1'b1:1'b0;

  /* always@(posedge clk)
    begin
      if(count==0)
        begin
          empty<=1;
          full<=0;
        end
      else if(count==8)
        begin
          empty<=0;
          full<=1;
        end
      else
        begin
          empty<=0;
          full<=0;
        end
    end*/


  //assign buff_out = (!empty && rd_en)? buffer[rd_ptr] : 16'hz;

  // counter
  always@(posedge clk or posedge rst)
    begin
      if(rst)
        count<=0;
      else if(!empty && rd_en && !full && wr_en)
        count<=count;   
      else if(!empty && rd_en)
        count<=count-1;
      else if(!full && wr_en)
        count<=count+1; 
      else
        count<=count;
    end
  
  // pointer
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

         if(!full && wr_en)
           wr_ptr<=wr_ptr+1;
       end
   end
  
  always@(posedge clk)
    begin
      if(!full && wr_en)
        buffer[wr_ptr]<=buff_in;
    end
  
  always@(posedge clk)
    begin
      if(!empty && rd_en)
        buff_out<=buffer[rd_ptr];
    end

   
   // writer
   
endmodule  

/*module fifoTester();

  reg clk,rst,rd_en,wr_en;
  reg[15:0] din;
  
  wire emp,ful;
  wire[15:0] dout;
  
  FifoBuffer dut(dout,emp,ful,din,wr_en,rd_en,clk,rst);
  
  initial
   begin
     clk=1'b0;
     forever
       #5 clk=~clk;
   end
  
  initial
    begin
      /*rst=1'b0; wr_en=1'b0; rd_en=1'b0; din=16'h0;
      
      #1 rst=1'b1; din=16'h16;

      #1 rst=1'b0; wr_en=1'b1;
      
      #10 din=16'h12;
      #10 din=16'h22;
      #10 din=16'h32;
      #10 din=16'h42;
      #10 din=16'h52;

          wr_en=1'b0; rd_en=1'b1;
      #50 wr_en=1'b1;rd_en=1'b0;

      #10 din=16'h62;
      #10 din=16'h72;
      #10 din=16'h82;
      #10 din=16'h92;
      #10 din=16'h102;
      #10 din=16'h112;
      #10 din=16'h212;
      #10 din=16'h312;
      #10 wr_en=1'b0; rd_en=1'b1;*/
       
     /* rst=1'b0;
      wr_en=1'b0;
      rd_en=1'b0;
      
      #2 rst=1'b1; 
      #1 rst=1'b0;
         din=16'h16;
      #2 wr_en=1'b1;
       rd_en=1'b0; 

      
      #10 din=16'h62;
      #10 din=16'h72;
      #10 din=16'h82;
      #10 din=16'h92;
      #10 din=16'h102; 
      #10 din=16'h112;
      #10 din=16'h122;
      #10 din=16'h132;
      #10 din=16'h142;
      #10 din=16'h152; 	
      #10 wr_en=1'b0; rd_en=1'b1;

    end
endmodule*/
   