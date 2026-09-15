module spi_slave_select(
//asynchronous low reset
input preset_n,
//indicates spi mode
input[1:0] spi_mode_i,
//master mode enable
input mstr_i,
//spi wait-in stop control
input spiswai_i,
//system clock
input pclk,
//indicates new data is written
input send_data_i,
//clock divisor for baud rate timing
input[11:0] BaudRateDivisor_i,
//slave select active low
output reg ss_o,
//flag to indicate data reception done
output reg receive_data_o,
//Transfer-in progress signal(active high when ss is low)
output tip_o
);
//internal signals
//Counter to track baudbased timing
reg[15:0] count_s;
//stores computed baud based count value (16*BaudRateDivisor)
wire[15:0] target_s;
//internal register to trigger recieve_data_o
reg rcv_s;
//target_s value assigned as product of 8 and BaudRateDivisor
assign target_s = BaudRateDivisor_i << 2'd3;
//tip_o is the compliment of ss_o
assign tip_o=~ss_o;
//block used to control the slave select signal(ss_o), count_s and rcv_s
always@(posedge pclk, negedge preset_n)
begin
	//reset (active low) logic
	if(!preset_n)
	begin
		count_s <= 16'hffff;
		ss_o <= 1;
		rcv_s <= 0;
	end
	else
	begin
		//mode conditions(operating in master mode and either in run mode(spi_mode_i=00) or wait mode(spi_mode_i=01) and spi_swai_i low)
		if(mstr_i && ((spi_mode_i == 2'b00)||(spi_mode_i ==2'b01)) && !spiswai_i)
		begin
			//asserting ss_o to 0 and to reset counter when data
			//transfer starts
			if(send_data_i)
			begin
				rcv_s <= 1'b0;
				ss_o <= 0;
				count_s <= 16'h0;
			end
			//increment count as data transfer occors and activate
			//slave and also assert rcv used to control recieve
			//data signal
			else if(count_s <= (target_s - 1'b1))
			begin
				count_s <= 1'b1 + count_s;
				ss_o <= 0;
				if(count_s == (target_s - 1'b1))
				begin
					rcv_s <= 1'b1;
				end
				else
				begin
					rcv_s <=1'b0;
				end
			end
			else
			//clearing to default values after count is equal to
			//target
			begin
				rcv_s <= 0;
				ss_o <= 1;
				count_s <= 16'hffff;
			end
		end
		//clearing values if the condition for data transfer is not
		//met
		else
		begin
			rcv_s <= 0;
			ss_o <= 1;
			count_s <= 16'hffff;
		end
	end
end

//generate receive_data_o signal
always@(posedge pclk, negedge preset_n)
begin
	//clearing value
	if(!preset_n)
	begin
		receive_data_o <= 1'b0;
	end
	//assigning rcv to recieve_data_o
	else
	begin
		receive_data_o <= rcv_s;
	end
end

endmodule




































 

