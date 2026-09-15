module shift_reg(
//APB Clock
input pclk,
//Active low asynchronous reset signal
input preset_n,
//slave select (active low clock)
input ss_i,
//indicates transfer of data (MOSI DATA) from shift register to data register
input receive_data_i,
//indicates the transfer of data from data register to shift register
input send_data_i,
//master in slave out
input miso_i,
//clock polarity
input cpol_i,
//clock phase
input cpha_i,
//lsb first enable
input lsbfe_i,
//miso receive flag posedge
input miso_receive_sclk_i,
//miso receive flag negedge
input miso_receive_sclk0_i,
//mosi send flag posedge
input mosi_send_sclk_i,
//mosi send flag negedge
input mosi_send_sclk0_i,
//MOSI data registe from data register to shift register
input[7:0] data_mosi_i,
//master output slave input
output reg mosi_o,
// MISO data from shift register
output[7:0] data_miso_o
);
// internal registers
// Holds the outgoing 8-bit data to shift on MOSI
reg[7:0] shift_register;
//Collects incoming 8-bit data from MISO
reg[7:0] temp_reg;
//3-Bit counters for MOSI shifting (LSB-first/MSB-first)
reg[2:0] count, count1;
//3-Bit counters for MISO shifting (LSB-first/MSB-first)
reg[2:0] count2, count3;
//data_miso_o loaded from temp reg after data is received
assign data_miso_o = receive_data_i ? temp_reg : 8'h00;
//Transmit data register logic(MOSI)(shift register load)
always@(posedge pclk, negedge preset_n) 
begin
	//reset condition
	if(!preset_n)
	begin
		shift_register <= 8'b0;
	end
	//transfer condition initiated
	else if(send_data_i)
	begin
		shift_register <= data_mosi_i;
	end
	//default condition
	else
	begin
		shift_register <= shift_register;
	end
end
//Parallel in serial out (PISO) for MOSI
always@(posedge pclk, negedge preset_n)
begin
	//asynchronous active low reset condition
	if(!preset_n)
	begin
		mosi_o <= 1'b0;
		count <= 3'd0;
		count1 <= 3'd7;
	end
	//reset count/count1 when ss is not asserted to low
	else if(ss_i)
	begin
		count <= 3'd0;
		count1 <= 3'd7;
	end
	//sampled at negedge
	else if((cpol_i && !cpha_i) || (!cpol_i && cpha_i))
	begin
		//lsb first
		if(lsbfe_i)
		begin
			//count end condition
			if(count<=3'd7)
			begin
				//flag to prepare data and increment count
				if(mosi_send_sclk0_i)
				begin
					mosi_o <= shift_register[count];
					count <= count + 1'b1;
				end
			end
			//reset count condition
			else
			begin
				count <= 3'd0;
			end
		end
		//msb first
		else
		begin
			//count1 end condition
			if(count1 >= 3'd0)
			begin
				//flag to increment count1 and prepare data
				if(mosi_send_sclk0_i)
				begin
					mosi_o <= shift_register[count1];
					count1 <= count1 - 1'b1;
				end
			end
			//count1 reset condition
			else
			begin
				count1 <= 3'd7;
			end
		end	
	end
	//sample at posedge
	else
	begin
		//lsb first
		if(lsbfe_i)
		begin
			//count end condition
			if(count<=3'd7)
			begin
				//flag to prepare data and increment count
				if(mosi_send_sclk_i)
				begin
					mosi_o <= shift_register[count];
					count <= count + 1'b1;
				end
			end
			//count reset condition
			else
			begin
				count <= 3'd0;
			end
		end
		//msb first
		else
		begin
			//count1 end condition
			if(count1 >= 3'd0)
			begin
				//mosi posedge flag
				if(mosi_send_sclk_i)
				begin
					mosi_o <= shift_register[count1];
					count1 <= count1 - 1'b1;
				end
			end
			//reset count1 flag
			else
			begin
				count1 <= 3'd7;
			end
		end	
		
	end
end
//serial in parallel out logic(SIPO) for MISO
always@(posedge pclk, negedge preset_n)
begin
	//asynchronous active low reset condition 
	if(!preset_n)
	begin
		temp_reg <= 8'b0;
		count2 <= 3'd0;
		count3 <= 3'd7;
	end
	//when slave select is not asserted to low
	else if( ss_i )
	begin
		count2 <= 3'd0;
		count3 <= 3'd7;
	end
	//driven at negedge
	else if((!cpha_i && cpol_i) || (cpol_i && !cpha_i))
	begin
		//lsb first
		if(lsbfe_i)
		begin
			//count2 end condition
			if(count2 <= 3'd7)
			begin
				//miso negedge flag
				if(miso_receive_sclk0_i)
				begin
					count2 <= count2 + 1'b1;
					temp_reg[count2] <= miso_i;
				end 
			end
			//reset condition
			else
			begin
				count2 <= 3'd0;
			end
		end
		//msb first
		else
		begin
			//count3 end condition
			if(count3 >= 3'd0)
			begin
				//miso negedge flag
				if(miso_receive_sclk0_i)
				begin
					count3 <= count3 - 1'b1;
					temp_reg[count3] <= miso_i;
				end
			end
			//count reset condition
			else
			begin
				count3 <= 3'd7;
			end
		end
	end
	//sample at posedge
	else 
	begin
		//lsb first
		if(lsbfe_i)
		begin
			//count2 end condition
			if(count2 <= 3'd7)
			begin
				//miso posedge flag
				if(miso_receive_sclk_i)
				begin
					count2 <= count2 + 1'b1;
					temp_reg[count2] <= miso_i;
				end 
			end
			//reset count2
			else
			begin
				count2 <= 3'd0;
			end
		end
		//msb first
		else
		begin
			//count3 end condition
			if(count3 >= 3'd0)
			begin
				//miso posedge flag
				if(miso_receive_sclk_i)
				begin
					count3 <= count3 - 1'b1;
					temp_reg[count3] <= miso_i;
				end
			end
			//count3 reset condition
			else
			begin
				count3 <= 3'd7;
			end
		end
	end
end
endmodule





