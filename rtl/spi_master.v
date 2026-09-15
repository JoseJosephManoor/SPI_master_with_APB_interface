//...................                  Global Definition list                            ...................//
`define SPI_APB_DATA_WIDTH   8
`define SPI_REG_WIDTH        8
`define SPI_APB_ADDR_WIDTH   3
//...................                   module declaration                              ...................//
module spi_master(

input pclk,
input preset_n,
input pwrite_i,
input psel_i,
input[`SPI_APB_ADDR_WIDTH-1:0] paddr_i,
input penable_i,
input[`SPI_REG_WIDTH-1:0] pwdata_i,
input miso_i,

output ss_o,
output sclk_o,
output spi_interrupt_request_o,
output mosi_o,
output [`SPI_APB_DATA_WIDTH-1:0] prdata_o,
output pslverr_o,
output pready_o
);
wire cpol,
     cpha,
     spiswai,
     miso_receive_sclk,
     miso_receive_sclk0,
     mosi_send_sclk,
     mosi_send_sclk0,
     mstr,
     send_data,
     receive_data,
     tip,
     lsbfe;

wire[11:0] BaudRateDivisor;
wire[2:0] spr,
          sppr;
wire[1:0] spi_mode;
wire[`SPI_APB_DATA_WIDTH-1:0] data_mosi,
                              data_miso;
//Baud Generator instantiation
spi_baud_generator m1
(
pclk,
preset_n,
cpol,
spiswai,
spi_mode,
spr,
sppr,
ss_o,
sclk_o,
BaudRateDivisor,
cpha,
miso_receive_sclk,
miso_receive_sclk0,
mosi_send_sclk,
mosi_send_sclk0
);
//slave select instantiation
spi_slave_select m2(
preset_n,
spi_mode,
mstr,
spiswai,
pclk,
send_data,
BaudRateDivisor,
ss_o,
receive_data,
tip
);

//Shift Register
shift_reg m3(
pclk,
preset_n,
ss_o,
receive_data,
send_data,
miso_i,
cpol,
cpha,
lsbfe,
miso_receive_sclk,
miso_receive_sclk0,
mosi_send_sclk,
mosi_send_sclk0,
data_mosi,
mosi_o,
data_miso
);

//APB slave interface
apb_slave_interface m4(

pclk,                                  
preset_n,                              
paddr_i,      
psel_i,				    
penable_i,                             
pwrite_i,                              
pwdata_i,          
ss_o,			             
receive_data,                        
data_miso,  
tip,                               

prdata_o,        
pready_o,                            
pslverr_o,                            
spi_interrupt_request_o,              
send_data,                         
mstr,           	                 
cpol,				        
cpha,                               
lsbfe,                             
spiswai,			    
data_mosi,      
spi_mode,                     
spr,                           
sppr                          

); 

endmodule

