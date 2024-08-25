`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/20/2024 02:12:52 AM
// Design Name: 
// Module Name: I2C_Protocol
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module I2C_Protocol(

 input clk, reset, newd,
 input [7:0] din,
 input [6:0] addr,
 input op,      // type of the operation 1 is for read and 0 is for write the data;
 inout  sda,    //
 output scl, 
 output [7:0] dout,
 output reg busy,
 output reg ack_err,
 output reg done
    );
    
reg scl_t = 0;   // store the clock bit to tx serially via single bit
reg sda_t = 0;   // store the signal bit of the sda line to transmit serially.

parameter sys_freq = 40000000; // 40Mhz
parameter i2c_freq = 100000;   // 100khz i2c frequency
 
parameter clk_count4 = (sys_freq/i2c_freq); // this show the signal bit duration during the transfor of data in I2C communication
parameter clk_count1 = clk_count4/4;        /// 100 clock pulses // 4 part fo the 4 samller duration

integer count1 = 0;  
reg i2c_clk = 0;

// each samller duration of the clock, that is 4, has the unique value, so there for 
reg [1:0] pulse = 0; // each duration of the pulse have the unique pulse values

// now generateing the pulses; with 4 different protion:

always @ (posedge clk)
begin
   if(reset)
   begin 
      pulse <= 0;
      count1 <= 0;
   end 
   else if (busy == 1'b0) // pulse count start only after the new data if exist
   begin 
      pulse <= 0;
      count1 <= 0;
   end 
   else if ( count1 == clk_count1 - 1)
       begin 
         pulse <= 1;
         count1 <= clk_count1 + 1;
      end 
      else if (count1 == clk_count1*2 - 1)
         begin
            pulse <= 2;
            count1<= count1+1;
         end 
          else if (count1 == clk_count1*3 - 1)
         begin
            pulse <= 3;
            count1<= count1+1;
         end 
           else if (count1 == clk_count1*4 - 1)
         begin
            pulse <= 0;
            count1<= 0;
         end  
         else 
         begin 
            count1 <= count1 +1;
         end
end 


reg [3:0] bitcount = 0;  // used to count the data bit that want to send by \I2c.
reg [7:0] data_addr = 0; // used to hold the address of the data
reg [7:0] data_tx = 0;   //
reg r_ack = 0;           // recived acknowlodge when get the recieved data
reg [7:0] rx_data = 0;   // output register used to recived the send data.
reg sda_en = 0;          // enable sda line to get the data to tx.

// // now the states for the transimission of data in I2C protocols
// typedef enum logic [3:0] {idle = 0, start = 1, write_addr = 2, ack_1 = 3, write_data = 4, read_data = 5, stop = 6, ack_2 =7, master_ack = 8} state_type;
// state_type state = idle;                     
//   /*ack_1 = 3 acknowlogement form a salve
//  ///  ack_2 = 7, // if write a data we need the 2nd acknowlodgement from a salves, 
//  // master_ack = 8, // if we need read the data we sent the master ack to the salves,*/
parameter idle       = 4'b0000;
parameter start      = 4'b0001;
parameter write_addr = 4'b0010;
parameter ack_1      = 4'b0011;
parameter write_data = 4'b0100;
parameter read_data  = 4'b0101;
parameter stop       = 4'b0110;
parameter ack_2      = 4'b0111;
parameter master_ack = 4'b1000;

reg [3:0] state = idle;  // State register initialized to idle

// starting the state machine to transform the data according to the I2C data fram
always@(posedge clk)
begin 
   if(reset)
   begin 
      bitcount  <= 0;
      data_addr <= 0;
      data_tx   <= 0;
      scl_t     <= 1;   // high for stop condition not clk generation
      sda_t     <= 1;   // high for data stop no bit to transfer
      state     <= idle; 
      busy      <= 1'b0; 
      ack_err   <= 1'b0;
      done      <= 1'b0;
   end
   else 
   begin 
      case (state)
         idle:
         begin 
            done    <= 1'b0;
            if(newd == 1'b1)              // new data is high then 
            begin 
               data_addr <= {addr, op};   // address of the devie and what is operatiion for reading or writing
               data_tx   <= din;          // data transfer to data_tx register
               busy      <= 1'b1;            // now the system is in busy
               state     <= start;          // state change form idle to start
               ack_err   <= 1'b0; 
            end 
            else 
            begin 
               data_addr <= 0;  // if no newdata then no address 
               data_tx   <= 0;    // no tx data 
               busy      <= 1'b0;    // not be busy 
               state     <= idle;   // in idle state
               ack_err   <= 1'b0; // no error 
            end 
         end
         //------------------------------------->>>>>>>>>>>>>>>>>>
         start:
         begin 
            sda_en <= 1'b1;     // enable the sda line pull to low for seding the data
              case(pulse)
               // this logic build the start condition for the i2C transfer of data
               // half of the clock it sent high and half of the clock it send low start condition 
               0: begin scl_t <= 1'b1; sda_t <= 1'b1; end 
               1: begin scl_t <= 1'b1; sda_t <= 1'b1; end 
               2: begin scl_t <= 1'b1; sda_t <= 1'b0; end 
               3: begin scl_t <= 1'b1; sda_t <= 1'b0; end 
               endcase 

               if (count1 == clk_count1*4 - 1) // at the last count it change the state  to write the address
               begin  // after completing the 4 pules duration it change to the start the write address
                  state <= write_addr;
                  scl_t <= 1'b0;
               end 
               else 
                  state <= start;  // otherwise in the same state start;
            end 
          
          //----------------------------------->>>>>>>>>>>>>>>>>>>>>>>>
          write_addr:
          begin
          sda_en <= 1'b1; // again sda line pull to low to send the address to salve
              if(bitcount <= 7)
              begin 
               case(pulse)
                  0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                  1: begin scl_t <= 1'b0; sda_t <= data_addr[7-bitcount]; end // sending address bit by bit in sda line upto 8 bits
                  2: begin scl_t <= 1'b1; end 
                  3: begin scl_t <= 1'b1; end
                  endcase
                     // sending the data on the first half of the clk pulse, and then wait for 399 count of the counter
                     // thus, to transfer the data, until we transmit all of the data.
               if(count1 == clk_count1*4 - 1)   // again for the last count it changes its state,
               begin 
               state    <= write_addr;
               scl_t    <= 1'b0;
               bitcount <= bitcount + 1;
            end 
                         else
                                 begin
                                    state <= write_addr;
                                 end
         end 
         else 
         begin
            state    <= ack_1; //after sending all the bit we move to the ack state
            bitcount <= 0; // bitcount to 0, to make used for next data
            sda_en   <= 1'b0; // for reciving the ack state, release the sda line.
         end 
      end 
      //--------------------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      ack_1 : 
                   begin
                        sda_en <= 1'b0; ///recv ack from slave , this sda pull down to low
                                case(pulse)
                                 0: begin scl_t <= 1'b0; sda_t <= 1'b0; end // for first two half the clock is low and sda line also low
                                 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end  //  '' 
                                 2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= 1'b0; end ///recv ack from slave 
                                 3: begin scl_t <= 1'b1;  end  // in this last two half the clock high, and ack from slwo is low mean acknowledge by the salve is done
                                 endcase
                   
                       if(count1  == clk_count1*4 - 1)
                                  begin
                                      if(r_ack == 1'b0 && data_addr[0] == 1'b0) // ack is done, and addres bit become zero mean we want to write data to slave.
                                        begin
                                        state    <= write_data;
                                        sda_t    <= 1'b0; // now data will be send to slave, for this sda line should be pull down to low
                                        sda_en   <= 1'b1; /////write data to slave
                                        bitcount <= 0; // start counting the bit to sent, for this bit count will be zero to start
                                        end
                                      else if (r_ack == 1'b0 && data_addr[0] == 1'b1)  // ack is low, and data addres is 1, then start reading from slave
                                      begin
                                        state    <= read_data;    
                                        sda_t    <= 1'b1;   // for reading the sda line pull up to high
                                        sda_en   <= 1'b0; ///read data from slave
                                        bitcount <= 0;  // for reading also we count the bit so bit count reg should be zero
                                      end
                                      else
                                      begin
                                        state   <= stop;   
                                        sda_en  <= 1'b1; ////send stop to slave
                                        ack_err <= 1'b1; // in stop state the there should be the ack high to indicate the no further acknowledge
                                      end
                                  end
                                 else
                                  begin
                                    state <= ack_1; // otherwise it will remain in this state
                      end   
                   end
///--------------------------------------------------------------------->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
// after sending the ack signal from slave we start writing data to the slave
    write_data: 
                 begin
                   ///write data to slave
                  if(bitcount <= 7) 
                         begin
                                 case(pulse)
                                 0: begin scl_t <= 1'b0;  end
                                 1: begin scl_t <= 1'b0;  sda_en <= 1'b1; // sda enable 1 pul down thesda line to low
                                        sda_t   <= data_tx[7 - bitcount]; end
                                 2: begin scl_t <= 1'b1;  end
                                 3: begin scl_t <= 1'b1;  end
                                 endcase
                                 if(count1  == clk_count1*4 - 1) // afte completing the clk duration ti send the next bits
                                 begin
                                    state    <= write_data;
                                    scl_t    <= 1'b0;
                                    bitcount <= bitcount + 1;
                                 end
                                 else
                                 begin
                                    state    <= write_data;
                                 end
                             
                         end
                      else
                        begin
                        state    <= ack_2; // ack from the salve when sending all the data to slave
                        bitcount <= 0;  // bit count is zero for next counts of data transfer.
                        sda_en   <= 1'b0; ///read from slave
                        end   
                 end 

     ///////////////////////////// when we want to read_data the data from the slaves
                 
                 read_data: 
                 begin
                 sda_en  <= 1'b0; ///read from slave, realse the line
                 if(bitcount <= 7)  // untile sent the or recieved all the bit it remain in state, that it is.
                         begin
                                 case(pulse)
                                 0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                 2: begin scl_t <= 1'b1; rx_data[7:0] <= (count1 == 200) ? {rx_data[6:0],sda} : rx_data; end
                                 3: begin scl_t <= 1'b1;  end
                                 endcase
                                 if(count1  == clk_count1*4 - 1)
                                 begin
                                    state    <= read_data;
                                    scl_t    <= 1'b0;
                                    bitcount <= bitcount + 1;
                                 end
                                 else
                                 begin
                                    state   <= read_data;
                                 end
                             
                         end
                      else
                        begin
                        state    <= master_ack; // after reading the complete data master ack, signal sent to the slove to stop the communications
                        bitcount <= 0;
                        sda_en   <= 1'b1; ///master will send ack to slave
                        end
                 
                 
                 
                 end
                 ////////////////////master ack -> send nack
                 master_ack : 
                   begin
                      sda_en <= 1'b1; // pull the line low
                      
                                case(pulse)
                                 0: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                                 1: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                                 2: begin scl_t <= 1'b1; sda_t <= 1'b1; end 
                                 3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                                 endcase
                   
                       if(count1  == clk_count1*4 - 1)
                                  begin
                                      sda_t  <= 1'b0;
                                      state  <= stop;
                                      sda_en <= 1'b1; ///send stop to slave
                                      
                                  end
                                 else
                                  begin
                                    state   <= master_ack;
                                  end
                     
                   end
                 
                 
                 
                 /////////////////ack 2 this is acknowlege from the slave the slave recieved the all the data now stop sending the data
                 
                  ack_2 : 
                   begin
                     sda_en <= 1'b0; ///recv ack from slave. pule line high or high impendance
                                case(pulse)
                                 0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                 1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                                 2: begin scl_t <= 1'b1; sda_t <= 1'b0; r_ack <= 1'b0; end ///recv ack from slave
                                 3: begin scl_t <= 1'b1;  end
                                 endcase
                   
                       if(count1  == clk_count1*4 - 1)
                                  begin
                                      sda_t    <= 1'b0;
                                      sda_en   <= 1'b1; ///send stop to slave
                                      if(r_ack == 1'b0 )
                                        begin
                                        state   <= stop;
                                        ack_err <= 1'b0;
                                        end
                                      else
                                        begin
                                        state   <= stop;
                                        ack_err <= 1'b1;
                                        end
                                  end
                                 else
                                  begin
                                    state <= ack_2;
                                  end
                     
                   end

                /////////////////////////////////////////////stop  
                   stop: 
                     begin
                     sda_en <= 1'b1; ///send stop to slave
                         case(pulse)
                         0: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                         1: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                         2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                         3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                         endcase
                         
                             if(count1  == clk_count1*4 - 1)
                             begin
                                state   <= idle;
                                scl_t   <= 1'b0;
                                busy    <= 1'b0;
                                sda_en  <= 1'b1; ///send start to slave
                                done    <= 1'b1;
                             end
                             else
                                state   <= stop;
                     end
                     
                     //////////////////////////////////////////////
                      
                 default : state <= idle;
               endcase
   end
end

assign sda = (sda_en == 1) ? (sda_t == 0) ? 1'b0 : 1'b1 : 1'bz; /// en = 1 -> write to slave else we read frome the salve
////// if sda_en == 1 then if sda_t == 0 pull line low else release so that pull up make line high
assign scl = scl_t;
assign dout = rx_data;

endmodule
 