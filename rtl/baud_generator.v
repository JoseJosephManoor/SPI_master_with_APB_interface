module spi_baud_generator
(
//system clock
input pclk,
//Active low asynchronous reset signal
input preset_n,
//clock polarity
input cpol_i,
//SPI stop in wait mode
input spiswai_i,
//SPI mode(run, wait and stop)
input[1:0] spi_mode_i,
//SPI baud rate selection bits
input[2:0] spr_i,
//SPI baud rate preselection bit
input[2:0] sppr_i,
//Slave select active low signal
input ss_i,
//serial clock
output reg sclk_o,
//Baud rate divisor
output[11:0] BaudRateDivisor_o,
//clock phase
input cpha_i,
//flag to indicate when to recieve the miso data when both cphase and cpol are
//high or low
output reg miso_receive_sclk_o,
//flag to indicate when to recieve the miso data when either cphase or cpol is
//high 
output reg miso_receive_sclk0_o,
//flag to indicate when to send mosi data when both cpol and cphase are high
//or low
output reg mosi_send_sclk_o,
//flag to indicate when to send mosi data when either cpol or cphase are high
output reg mosi_send_sclk0_o
);
//initial polarity for sclk_o
wire pre_sclk_s;
//12-bit counter  for baud rate control
reg[11:0] count_s;
//baud rate divisor
assign BaudRateDivisor_o = (sppr_i + 1) << (spr_i + 1);
//initial sclk polarity
assign pre_sclk_s = cpol_i ? 1'b1 : 1'b0;

//serial clk
always@(posedge pclk or negedge preset_n)
begin
        //reset logic
	if(!preset_n)
	begin
		count_s <= 12'b0;
		sclk_o <= pre_sclk_s;
	end
        //count logic
        else if( (!ss_i) && (!spiswai_i) && ((spi_mode_i == 2'b00) || (spi_mode_i == 2'b01)))
	begin
		if(((BaudRateDivisor_o >> 1'b1) - 1'b1) == count_s)
		begin
			sclk_o <= ~sclk_o;
			count_s <= 12'b0;
		end
		else
		begin
			count_s <= count_s+1'b1;
		end
	end
        //holding sclk and reseting count when sclk is not being generated
	else
	begin
		sclk_o <= pre_sclk_s;
		count_s <= 12'b0;
	end
end

//generate MISO sample flags
always@(posedge pclk or negedge preset_n)
begin
	//reset logic
	if(!preset_n)
	begin
		miso_receive_sclk_o <= 1'b0;	
		miso_receive_sclk0_o <= 1'b0;	
	end

      	// miso_receive_sclk0_o flag
        else if(((!cpha_i) && (cpol_i)) || ((cpha_i) && (!cpol_i)))
	begin
            	//asserting miso_receive_sclk0_o flag for 1 pclk
		if(sclk_o && (count_s == ((BaudRateDivisor_o >> 1'b1) - 1'b1)))
		begin
			miso_receive_sclk0_o <= 1'b1; 	
		end 
               	//clearing miso flags
		else
		begin
			miso_receive_sclk0_o <= 1'b0;
			miso_receive_sclk_o <= 1'b0;
		end
	end
        //miso_receive_sclk_o flag 
	else if( ((!cpha_i) && (!cpol_i)) || ((cpha_i) && (cpol_i)) )
	begin
                //asserting miso_receive_sclk_o flag for 1 pclk
                if( (!sclk_o) && (count_s == ((BaudRateDivisor_o >> 1'b1) - 1'b1)))
		begin
			miso_receive_sclk_o <= 1'b1; 	
		end 
                //clearing miso flags
		else
		begin
			miso_receive_sclk_o <= 1'b0;
			miso_receive_sclk0_o <= 1'b0;

		end
	end
end
//generate MOSI sample flags
always@(posedge pclk or negedge preset_n)
begin
	//reset logic
	if(!preset_n)
	begin
		mosi_send_sclk_o <= 1'b0;	
		mosi_send_sclk0_o <= 1'b0;	
	end
      	// mosi_send_sclk0_o flag
        else if(((!cpha_i) && (cpol_i)) || ((cpha_i) && (!cpol_i)))
	begin
       		//asserting mosi_send_sclk0_o flag for 1 pclk
		if(sclk_o && (count_s == ((BaudRateDivisor_o >> 1'b1) - 2'b10)))
		begin
			mosi_send_sclk0_o <= 1'b1; 	
		end 
               	//clearing mosi flag
		else
		begin
			mosi_send_sclk0_o <= 1'b0;
			mosi_send_sclk_o <= 1'b0;
		end
	end
        //mosi_send_sclk_o flag 
	else if( ((!cpha_i) && (!cpol_i)) || ((cpha_i) && (cpol_i)) )
	begin
               	//asserting mosi_send_sclk_o flag for 1 pclk
               	if( (!sclk_o) && (count_s == ((BaudRateDivisor_o >> 1'b1) - 2'b10)))
		begin
			mosi_send_sclk_o <= 1'b1; 	
		end 
               	//clearing mosi flag
		else
		begin
			mosi_send_sclk_o <= 1'b0;
			mosi_send_sclk0_o <= 1'b0;
		end
	end
end
endmodule

