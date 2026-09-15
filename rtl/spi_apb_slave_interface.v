//...................                   module declaration                              ...................//

module apb_slave_interface(

//...................                    input signal list                              ...................//

input pclk,                                  //system clock
input preset_n,                              //active low asynchronous reset
input[2:0] paddr_i,      //APB address bus
input psel_i,				     //APB Slave select signal
input penable_i,                             //PENABLE indicates thr second and subsequent APB transfer
input pwrite_i,                              //indicates the write(1) or read(0)
input[7:0] pwdata_i,          //The PWDATA is write data bus
input ss_i,			             //Slave select(Active low signal)
input receive_data_i,                        //Indicates the transfer of data(MISO data) from shift register 
					     //to transfer register
input[7:0] miso_data_i,  //MISO data from shift register
input tip_i,                                 //Transfer in progress

//...................                    output signal list                             ...................//

output reg [7:0] prdata_o,        //The PRDATA is read data bus
output reg pready_o,                             //PREADY is used to extend an APB transfer by core
output reg pslverr_o,                            //PSLVERR is used to indicate transfer error
output reg spi_interrupt_request_o,              //SPI interrupt request
output reg send_data_o,                          //Indicates the transfer of data(MOSI data) from data register 
					         //to shift register
output mstr_o,           	                 //Indicates Master(1) and Slave(0)
output cpol_o,				         //Clock Polarity	
output cpha_o,                               //clock phase
output lsbfe_o,                              //LSB first enable
output spiswai_o,			     //SPI stop in wait mode
output reg [7:0] mosi_data_o,      //MOSI Data from data register to shift register
output reg [1:0] spi_mode_o,                      //SPI Mode(RUN mode, Wait_Mode, Stop Mode)
output[2:0] spr_o,                           //SPI baud rate selection bit
output[2:0] sppr_o                           //SPI Baud Rate preselection bits

); 

//...................                      Memory map address                           ...................//

parameter SPICR1 = 3'b000,                     //SPI Control Register 1 Address
          SPICR2 = 3'b001,                     //SPI Control Register 2 Address
          SPIBR = 3'b010,                      //SPI Baud Rate Register Address
          SPISR = 3'b011,                      //SPI Status Register Address
          SPIDR = 3'b101;                      //SPI Data Register Address
          
//...................                     Control register Parameters                   ...................//

parameter SPIE = 3'b111,                       //CR1(SPI interrupt enable)
          SPE = 3'b110,                        //CR1(SPI System enable)
          SPTIE = 3'b101,                      //CR1(SPI Transmit Interrupt bit)  
          MSTR = 3'b100,                       //CR1(SPI Master/Slave mode select)
          CPOL = 3'b011,                       //CR1(SPI Clock Polarity bit)
          CPHA = 3'b010,                       //CR1(SPI Clock Phase bit)
          SSOE = 3'b001,                       //CR1(Slave Select Output Enable)
          LSBFE = 3'b000;                      //CR1(LSB - First Enable)

parameter MODFEN = 3'b100,                     //CR2(Mode Fault Enable Bit)
          BIDIROE = 3'b011,                    //CR2(Output Enable in Bidirectional mode of operation)
          SPISWAI = 3'b001,                    //CR2(SPI Stop in wait mode)
          SPC0 = 3'b000;                       //CR2(Serial Pin Control Bit 0)
                        
//...................                   Baud Rate Register Parameters                   ...................//

//...................                  SPI Baud Rate Preselection Bits                  ...................//

parameter SPPR2 = 3'b110,
          SPPR1 = 3'b101,
          SPPR0 = 3'b100;

//...................                   SPI Baud Rate Selection Bits                    ...................//

parameter SPR2 = 3'b010,
          SPR1 = 3'b001,
          SPR0 = 3'b000;

//...................                 SPI Status Register Parameters                    ...................//

parameter SPIF = 3'b111,                     //SPI Interrupt Flag
          SPTEF = 3'b101,                    //SPI Transmit Empty Interrupt Flag
          MODF = 3'b100;                     //Mode Fault Flag

//...................                      Masking parameters                           ...................//

parameter CR2MASK = 8'b00011011,             //Control Register 2 Mask
          BRMASK = 8'b01110111;              //Baud Rate Register Mask
 
//...................                       FSM parameters                              ...................//

parameter IDLE=2'b00,                        //APB FSM(IDLE State)
	  SETUP=2'b01,                       //APB FSM(SETUP State)
	  ENABLE=2'b10;                      //APB FSM(ENABLE State)

parameter SPI_RUN=2'b00,                     //SPI mode(RUN mode)
          SPI_WAIT=2'b01,                    //SPI mode(WAIT mode)
          SPI_STOP=2'b10;                    //SPI mode(STOP mode)

//...................                    Internal Registers                             ...................//

reg[1:0]                state, next_state;                   //APB FSM(APB State registers)
reg[1:0]                next_mode;                           //SPI FSM(SPI mode state)
reg[7:0] spi_cr_1,spi_cr_2;                   //SPI Control Registers
reg[7:0] spi_br;                              //SPI Baud Rate Register
reg[7:0] spi_sr;                              //SPI Status Register
reg[7:0] spi_dr;                              //SPI Data Register
reg                     rd_en;                               //Read Enable
reg                     wr_en;                               //Write Enable

//...................                      Internal wires                                ...................//

wire                    spif;                                //SPI Interrupt Flag
wire                    sptef;                               //SPI Transmit Interrupt Flag
wire                    modf;                                //SPI Mode Fault Flag

//...................                       APB interface FSM                           ...................//

//...                       Sequential logic for changing state and reset logic                         ...//

always@(posedge pclk, negedge preset_n)
begin
   if(!preset_n)
   begin
      state <= IDLE;
   end
   else
   begin
      state <= next_state;
   end    
end

//...                       Combinational Logic for next_state in APB interface fsm                     ...//

always@(*)
begin
   case(state)
      IDLE:  begin
                if(!penable_i && psel_i)
                begin
                   next_state = SETUP;
                end
                else
                begin
                   next_state = IDLE;
                end
             end
      SETUP: begin
                if(psel_i && penable_i)
                begin
                   next_state = ENABLE;
                end
                else if(psel_i && !penable_i)
                begin
                   next_state = SETUP;
                end
                else
                begin
                   next_state = IDLE;
                end
             end
      ENABLE:begin
                if(psel_i)
                begin
                   next_state = SETUP;
                end
                else
                begin
                   next_state = IDLE;  
                end
             end
      default:begin
                 next_state = IDLE; 
              end
   endcase
end

//...                                               SPI mode FSM                                          ...//

always@(posedge pclk, negedge preset_n)
begin
   if(!preset_n)
   begin
      spi_mode_o <= SPI_RUN;
   end
   else
   begin
      spi_mode_o <= next_mode;
   end
end

//...                           Combinational Logic for next_mode in SPI mode fsm                          ...//

always@(*)
begin
   case(spi_mode_o)
      SPI_RUN: begin
                  if(!spi_cr_1[SPE])
                  begin
                     next_mode = SPI_WAIT; 
                  end
                  else
                  begin
                     next_mode = SPI_RUN;
                  end
               end
      SPI_WAIT:begin
                  if(spi_cr_2[SPISWAI])
                  begin
                     next_mode = SPI_STOP;
                  end
                  else if(spi_cr_1[SPE])
                  begin
                     next_mode = SPI_RUN;
                  end
                  else if(!spi_cr_1[SPE])
                  begin
                     next_mode = SPI_WAIT;
                  end
                  else
                  begin
                     next_mode = SPI_RUN;
                  end
               end
      SPI_STOP:begin
                  if(spi_cr_1[SPE])
                  begin
                     next_mode = SPI_RUN;
                  end
                  else if(!spi_cr_2[SPISWAI])
                  begin
                     next_mode = SPI_WAIT;
                  end
                  else
                  begin
                     next_mode = SPI_STOP;   
                  end                 
               end
      default:begin
                 next_mode = SPI_RUN; 
              end 
   endcase
end

//...                         Read(rd_en)/Write(wr_en) when APB state is ENABLE                           ...//

always@(*)
begin
   if((state == ENABLE) &&  pwrite_i)
   begin
      wr_en = 1'b1;
      rd_en = 1'b0;
   end
   else if((state == ENABLE) && !pwrite_i)
   begin
      rd_en = 1'b1;
      wr_en = 1'b0;
   end
   else
   begin
      rd_en = 1'b0;
      wr_en = 1'b0; 
   end
end

//...                                         PSLVERR/PREADY                                              ..//

always@(*)
begin
   if(state == ENABLE)
   begin
      pslverr_o = ~tip_i;
      pready_o = 1'b1;
   end
   else
   begin
      pslverr_o = 1'b0;
      pready_o = 1'b0;
   end
end

//...                                       APB Write Data Path                                           ...//

always@(posedge pclk, negedge preset_n)
begin
   if(!preset_n)
   begin
      spi_cr_1 <= 8'h04;
      spi_cr_2 <= 8'h00;
      spi_br   <= 8'h00;
   end
   else
   begin
      if(wr_en)
      begin
         if(paddr_i == SPICR1)
         begin
            spi_cr_1 <= pwdata_i;
         end
         else if(paddr_i == SPICR2)
         begin
            spi_cr_2 <= pwdata_i & CR2MASK;
         end
         else if(paddr_i == SPIBR)
         begin
            spi_br <= pwdata_i & BRMASK;
         end
         else
         begin
            spi_cr_1 <= spi_cr_1;
            spi_cr_2 <= spi_cr_2;
            spi_br <= spi_br;
         end
      end
      else
      begin
         spi_cr_1 <= spi_cr_1;
         spi_cr_2 <= spi_cr_2;
         spi_br <= spi_br;
        /* spi_cr_1 <= 8'h04;
         spi_cr_2 <= 8'h04;
         spi_br   <= 8'h00;*/
      end
   end   
end
 
//...................                      APB Read Data Path                             ...................//

always@(*)
begin
   if(rd_en)
   begin
      if(paddr_i == SPICR1)
      begin
         prdata_o = spi_cr_1;
      end
      else if(paddr_i == SPICR2)
      begin
         prdata_o = spi_cr_2;
      end
      else if(paddr_i == SPIBR)
      begin
         prdata_o = spi_br;
      end
      else if(paddr_i == SPISR)
      begin
         prdata_o = spi_sr;
      end
      else if(paddr_i == SPIDR)
      begin
         prdata_o = spi_dr;
      end
      else
      begin
         prdata_o = 8'h00;
      end
   end
   else
   begin
      prdata_o = 8'h00;
   end
end

//...................                      Status Register                              ...................//

//...................                       Status Flags                                ...................//

assign modf = (spi_cr_1[MODFEN] && !spi_cr_1[SSOE] && spi_cr_1[MSTR] && !ss_i); //Mode Fault Flag

assign spif = (spi_dr != {8{1'b0}});                               //SPI Interrupt Flag
                                
assign sptef = (spi_dr == {8{1'b0}});                              //SPI Transmit Interrupt Flag

//...................                 Writing to Status register                        ...................//

always@(*)
begin
   if(!preset_n)
   begin
      spi_sr = 8'b0010_0000;
   end
   else 
   begin
      spi_sr = {spif,1'b0,sptef,modf,4'b0};
   end
end

//...................                      Data Register                              ...................//
//spi data register has to be reset after getting miso_data_i
always@(posedge pclk, negedge preset_n)
begin
   if(!preset_n)
   begin
      spi_dr <= 8'b0000_0000;
   end
   else
   begin
      if(wr_en)
      begin
         if(paddr_i == 3'b101)
         begin
            spi_dr <= pwdata_i;
         end
         else
         begin
            spi_dr <= spi_dr;        
         end
      end
      else
      begin
         if(receive_data_i && ((spi_mode_o == SPI_RUN) || (spi_mode_o == SPI_WAIT)))
         begin
            spi_dr <= miso_data_i;
         end
         else
         begin
			   if(((spi_mode_o == SPI_RUN) || (spi_mode_o == SPI_WAIT)) && (spi_dr != miso_data_i) && (spi_dr == pwdata_i)) 
            begin
               spi_dr <= 8'b0000_0000;
            end
            else
            begin
               spi_dr <= spi_dr;
            end
         end
      end
   end
end

//...................                send data signal generation                    ...................//
//Note:send data is only was ss goes low that means slave select is flawed

always@(posedge pclk, negedge preset_n)
begin
   if(!preset_n)
   begin
      send_data_o <= 1'b0;
   end
   else
   begin
      if(!wr_en)
      begin
         if(((spi_mode_o == SPI_RUN) || (spi_mode_o == SPI_WAIT)) && (spi_dr != miso_data_i) && (spi_dr == pwdata_i))
         begin
            send_data_o <= 1'b1;
         end
         else 
         begin
            send_data_o <= 1'b0;
         end
      end
      else
      begin
         send_data_o <= 1'b0;
      end
   end
end

//...................                   MOSI data Output Path                     ...................//

always@(posedge pclk, negedge preset_n)
begin
   if(!preset_n)
   begin
      mosi_data_o <= 8'b0000_0000; 
   end
   else
   begin 
      if(((spi_mode_o == SPI_RUN) || (spi_mode_o == SPI_WAIT)) && (spi_dr != miso_data_i) && (spi_dr == pwdata_i))
      begin
         mosi_data_o <= spi_dr;
      end
      else
      begin
         mosi_data_o <= mosi_data_o;
      end
   end
end

//...................                   SPI Interrupt Request                     ...................//

always@(*)
begin
   if(!spi_cr_1[SPIE] && !spi_cr_1[SPTIE])
   begin
      spi_interrupt_request_o = 1'b0;
   end
   else
   begin   
      if(spi_cr_1[SPIE] && !spi_cr_1[SPTIE])
      begin
         spi_interrupt_request_o = (spif || modf);
      end
      else
      begin
         if(!spi_cr_1[SPIE] && spi_cr_1[SPTIE])
         begin
            spi_interrupt_request_o = sptef;
         end
         else
         begin
            spi_interrupt_request_o = (sptef || spif || modf);
         end
      end
   end
end

//...................                Decode Output from Register                  ...................//

assign mstr_o = spi_cr_1[MSTR];

assign cpol_o = spi_cr_1[CPOL];

assign cpha_o = spi_cr_1[CPHA];

assign lsbfe_o = spi_cr_1[LSBFE];

assign spiswai_o = spi_cr_2[SPISWAI];

assign spr_o = {spi_br[SPR2],spi_br[SPR1],spi_br[SPR0]};

assign sppr_o = {spi_br[SPPR2],spi_br[SPPR1],spi_br[SPPR0]}; 

endmodule

