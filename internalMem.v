`define IGNORE

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
				output reg[DMD_SIZE-1:0] dm_bc_dt     // Data Memory Data Out
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
		always@(posedge clk)
		begin
			if(ps_dm_cslt && ~ps_dm_wrb)
			begin
					dm_bc_dt<=dmData[dg_dm_add];
			end
		end
		//assign dm_bc_dt= (ps_dm_cslt && ~ps_dm_wrb)? dmData[dg_dm_add]: 16'hz ;

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