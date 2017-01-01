LIBRARY ieee;
USE ieee.std_logic_1164.all;

--
-- Master Controller FSM implementation for the I2C Bus protocol
-- Version 2
-- Anton Nefedenkov (ain2108)
-- Emmanuel Koumandakis (ek2808)
--

ENTITY MasterControllerFSMv2 is
PORT (Clk_hi:         IN STD_LOGIC;
      -- BUS INPUTS
      SDA_in:        IN STD_LOGIC;
      SCL_in:        IN STD_LOGIC;
      -- DATA INPUT
      bit_send:      IN STD_LOGIC;
      -- COUNTER INPUT
      SCL_toggle:    IN STD_LOGIC;
      byte_done:     IN STD_LOGIC;
      start:         IN STD_LOGIC;
      
      -- TO SCL
      SCL_out:       OUT STD_LOGIC;
      SCL_enable:    OUT STD_LOGIC;
      -- TO SDA
      SDA_out:       OUT STD_LOGIC;
      SDA_enable:    OUT STD_LOGIC;
      -- DATA OUT
      data_received: OUT STD_LOGIC;
      -- TO CONTROLLER
      cnt_enable:    OUT STD_LOGIC);
END MasterControllerFSMv2;


ARCHITECTURE ArchMCFSMv2 of MasterControllerFSMv2 is
TYPE State_type IS
    ( INIT,                   -- Initialization state
      ST1,                    -- Master is awoken
      ST2,                    -- Send start symbol
      
      -- Sending the address to the slave
      ADDR0,                  -- Sending 0 addr bit, pull SDA 
      ADDR1,                  -- Sent 0 addr bit
      ADDR2,                  -- Pulse wait after sending 0
      ADDR3,                  -- Ready to send 0 addr bit
      ADDR4,                  -- Readt to send 1 addr bit
      ADDR5,                  -- Sending 1 bit, pull SDA
      ADDR6,                  -- Sent 1 addr bit
      ADDR7,                  -- Pulse wait after sending 1
      
      -- Sending the READ(1)/WRITE(0)
      RB0,                    -- Sending READ(1), pull SDA
      RB1,                    -- Ready to send READ(1)
      RB2,                    -- Sent READ(1)
      RB3,                    -- Pulse wait after READ(1)
            
      WB0,                    -- Ready to send WRITE(0)
      WB1,                    -- Sending WRITE(0), pull SDA
      WB2,                    -- Sent WRITE(0)
      WB3,                    -- Pulse wait after WRITE(0)
      
      -- Acking the address transmission
      RB_ACK0,                 -- Slave can send the ACK
      RB_ACK1,                 -- ACK is stable
      RB_ACK2,                 -- ACKED
      RB_NACK,                 -- NACKED
      
      WB_ACK0,                 -- Slave can send the ACK
      WB_ACK1,                 -- ACK is stable
      WB_ACK2,                 -- ACKED
      WB_NACK,                 -- NACKED 
      
      -- Reading data from the slave
      EVEN_RD0,                -- Start reading of bit
      EVEN_RD1,                -- Bit from slave is stable
      EVEN_RD2,                -- Bit read is 0 data bit
      EVEN_RD3,                -- Bit read is 1 data bit

      ODD_RD0,                -- Start reading of bit
      ODD_RD1,                -- Bit from slave is stable
      ODD_RD2,                -- Bit read is 0 data bit
      ODD_RD3,                -- Bit read is 1 data bit

      -- Reading the parity bit
      EVEN_RD_L0,             -- Start reading of bit
      EVEN_RD_L1,             -- Bit from slave is stable
      EVEN_RD_L2,             -- Bit read is 0 data bit
      EVEN_RD_L3,             -- Bit read is 1 data bit

      ODD_RD_L0,              -- Start reading of bit
      ODD_RD_L1,              -- Bit from slave is stable
      ODD_RD_L2,              -- Bit read is 0 data bit
      ODD_RD_L3,              -- Bit read is 1 data bit
      
      -- RETRAMSMISSION
      RE_EVEN_RD0,                -- Start reading of bit
      RE_EVEN_RD1,                -- Bit from slave is stable
      RE_EVEN_RD2,                -- Bit read is 0 data bit
      RE_EVEN_RD3,                -- Bit read is 1 data bit

      RE_ODD_RD0,                -- Start reading of bit
      RE_ODD_RD1,                -- Bit from slave is stable
      RE_ODD_RD2,                -- Bit read is 0 data bit
      RE_ODD_RD3,                -- Bit read is 1 data bit

      -- Reading the parity bit
      RE_EVEN_RD_L0,             -- Start reading of bit
      RE_EVEN_RD_L1,             -- Bit from slave is stable
      RE_EVEN_RD_L2,             -- Bit read is 0 data bit
      RE_EVEN_RD_L3,             -- Bit read is 1 data bit

      RE_ODD_RD_L0,              -- Start reading of bit
      RE_ODD_RD_L1,              -- Bit from slave is stable
      RE_ODD_RD_L2,              -- Bit read is 0 data bit
      RE_ODD_RD_L3,              -- Bit read is 1 data bit
      
      -- Writing data to slave
      WR0,                     -- Sending 0, pull SDA
      WR1,                     -- Ready to send 0
      WR2,                     -- Sent 0 data bit
      WR3,                     -- Pulse wait after sending 0
      WR4,                     -- Ready to send 1
      WR5,                     -- Sending 1, pull SDA
      WR6,                     -- Sent 1 data bit
      WR7,                     -- Pulse wait after sending 1
      
      
      -- Writing the last bit
      WR_L0,                   -- Sending last 0, pull SDA
      WR_L1,                   -- Ready to send last 0
      WR_L2,                   -- Sent last 0
      WR_L3,                   -- Pulse wait after sending last 0
      WR_L4,                   -- Ready to send last 1
      WR_L5,                   -- Sending last 1, pull SDA
      WR_L6,                   -- Sent last 1
      WR_L7,                   -- Pulse wait after sending last 1
      
      -- Reading the slave's ACK
      WR_ACK0,                 -- SDA disabled, waiting for slave
      WR_ACK1,                 -- Slave's ACK stable
      WR_ACK2,                 -- ACKED
      WR_NACK,                 -- NACKED

    -- RE_WRiting data to slave
      RE_WR0,                     -- Sending 0, pull SDA
      RE_WR1,                     -- Ready to send 0
      RE_WR2,                     -- Sent 0 data bit
      RE_WR3,                     -- Pulse wait after sending 0
      RE_WR4,                     -- Ready to send 1
      RE_WR5,                     -- Sending 1, pull SDA
      RE_WR6,                     -- Sent 1 data bit
      RE_WR7,                     -- Pulse wait after sending 1
      
      
      -- RE_WRiting the last bit
      RE_WR_L0,                   -- Sending last 0, pull SDA
      RE_WR_L1,                   -- Ready to send last 0
      RE_WR_L2,                   -- Sent last 0
      RE_WR_L3,                   -- Pulse wait after sending last 0
      RE_WR_L4,                   -- Ready to send last 1
      RE_WR_L5,                   -- Sending last 1, pull SDA
      RE_WR_L6,                   -- Sent last 1
      RE_WR_L7,                   -- Pulse wait after sending last 1
      
      -- Reading the slave's ACK
      RE_WR_ACK0,                 -- SDA disabled, waiting for slave
      RE_WR_ACK1,                 -- Slave's ACK stable
      RE_WR_ACK2,                 -- ACKED
      RE_WR_NACK,                 -- NACKED
      
      -- Writing the ACK to the slave
      RD_ACK0,                 -- Ready to send the ACK
      RD_ACK1,                 -- Sending the ACK, SDA pull
      RD_ACK2,                 -- ACK is stable
      RD_ACK3,                 -- Pulse wait after writing the ACK

      RD_NACK0,                 -- Ready to send the NACK
      RD_NACK1,                 -- Sending the NCK, SDA pull
      RD_NACK2,                 -- NACK is stable
      RD_NACK3,                 -- Pulse wait after writing the NACK
      
      RE_RD_ACK0,                 -- Ready to send the ACK
      RE_RD_ACK1,                 -- Sending the ACK, SDA pull
      RE_RD_ACK2,                 -- ACK is stable
      RE_RD_ACK3,                 -- Pulse wait after writing the ACK

      RE_RD_NACK0,                 -- Ready to send the NACK
      RE_RD_NACK1,                 -- Sending the NCK, SDA pull
      RE_RD_NACK2,                 -- NACK is stable
      RE_RD_NACK3,                 -- Pulse wait after writing the NACK
     
      -- Sending the STOP signal
      STOP0,               
      STOP1,
      STOP2,
      STOP3);

SIGNAL state : State_type;

BEGIN
    PROCESS(Clk_hi)
    BEGIN
      IF (Clk_hi'EVENT AND Clk_hi='1') THEN
        CASE state IS
          --
          -- MASTER CONTROLLER TURNS ACTIVE
          --
          WHEN INIT =>                   -- Initialization state
              IF start = '1' THEN
                  state <= ST1;
              ELSE 
                  state <= INIT;
              END IF;
              
          WHEN ST1 =>                    -- Master is awoken
              state <= ST2;
              
          WHEN ST2 =>                    -- Send start symbol
              IF SCL_toggle = '1' THEN
                  IF bit_send = '0' THEN
                      state <= ADDR0;
                  ELSIF bit_send = '1' THEN
                      state <= ADDR4;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= ST2;
              ELSE
					state <= INIT;
              END IF;

          --
          -- SEND SLAVE ADDRESS 
          --    
          WHEN ADDR0 =>                  -- Sending 0 addr bit => pull SDA 
              IF SCL_toggle = '0' THEN
                  state <= ADDR1;
              ELSIF SCL_toggle = '1' THEN
                  state <= ADDR0;
              ELSE
					state <= INIT;
              END IF;    

          WHEN ADDR1 =>                  -- Sent 0 addr bit
              state <= ADDR2;
              
          WHEN ADDR2 =>                  -- Pulse wait after sending 0
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' and bit_send = '0' THEN
                      state <= ADDR0;
                  ELSIF byte_done = '0' and bit_send = '1' THEN
                      state <= ADDR4;
                  ELSIF byte_done = '1' and bit_send = '0' THEN
                      state <= WB1;
                  ELSIF byte_done = '1' and bit_send = '1' THEN
                      state <= RB1;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= ADDR2;
              ELSE
					state <= INIT;
              END IF;

          WHEN ADDR3 =>                  -- Ready to send 0 addr bit
              state <= ADDR0;
              
          WHEN ADDR4 =>                  -- Readt to send 1 addr bit
              state <= ADDR5;
              
          WHEN ADDR5 =>                  -- Sending 1 bit => pull SDA
              IF SCL_toggle = '0' THEN
                  state <= ADDR6;
              ELSIF SCL_toggle = '1' THEN
                  state <= ADDR5;
              ELSE
					state <= INIT;
              END IF;

          WHEN ADDR6 =>                  -- Sent 1 addr bit
              state <= ADDR7;
              
          WHEN ADDR7 =>                  -- Pulse wait after sending 1
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' and bit_send = '0' THEN
                      state <= ADDR3;
                  ELSIF byte_done = '0' and bit_send = '1' THEN
                      state <= ADDR5;
                  ELSIF byte_done = '1' and bit_send = '0' THEN
                      state <= WB0;
                  ELSIF byte_done = '1' and bit_send = '1' THEN
                      state <= RB0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= ADDR7;
              ELSE
					state <= INIT;
              END IF;

			--
			-- SEND R/W BIT
			-- 
          WHEN RB0 =>                    -- Sending READ(1) => pull SDA
          	IF SCL_toggle='0' THEN
                  state <= RB2;
              ELSIF SCL_toggle='1'THEN
                  state <= RB0;
              ELSE
                  state <= INIT;
              END IF;
                
     			WHEN RB1 =>                    -- Ready to send READ(1)
                	state <= RB0;
     
     			WHEN RB2 =>                    -- Sent READ(1)
                	state <= RB3;
     
     			WHEN RB3 =>                    -- Pulse wait after READ(1)
                	IF SCL_toggle='1' THEN
                        state <= RB_ACK0;
                    ELSIF SCL_toggle='0'THEN
                        state <= RB3;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN WB0 =>                    -- Ready to send WRITE(0)
                	state <= WB1;
     
                WHEN WB1 =>                    -- Sending WRITE(0) => pull SDA
                	IF SCL_toggle='0' THEN
                        state <= WB2;
                    ELSIF SCL_toggle='1'THEN
                        state <= WB1;
                    ELSE
                        state <= INIT;
                    END IF;
     
              	WHEN WB2 =>                    -- Sent WRITE(0)
                	state <= WB3;
     
     			WHEN WB3 =>                    -- Pulse wait after WRITE(0)
                	IF SCL_toggle='1' THEN
                        state <= WB_ACK0;
                    ELSIF SCL_toggle='0'THEN
                        state <= WB3;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN RB_ACK0 =>                 -- Slave can send the ACK
                	IF SCL_toggle='0' THEN
                        state <= RB_ACK1;
                    ELSIF SCL_toggle='1'THEN
                        state <= RB_ACK0;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN RB_ACK1 =>                 -- ACK is stable
                	IF SDA_in = '0' THEN
     					state <= RB_ACK2;
     				ELSIF SDA_in = '1' THEN
     				    state <= RB_NACK;
     				ELSE
     					state <= INIT;
     				END IF;
     
     			WHEN RB_ACK2 =>                 -- ACKED
                	IF SCL_toggle='1' THEN
                        state <= EVEN_RD0;
                    ELSIF SCL_toggle='0'THEN
                        state <= RB_ACK2;
                    ELSE
                        state <= INIT;
                    END IF;
                
                WHEN RB_NACK =>                 -- NACK
                    IF SCL_toggle='1' THEN
                        state <= STOP0;
                    ELSIF SCL_toggle='0'THEN
                        state <= RB_NACK;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN WB_ACK0 =>                 -- Slave can send the ACK
                	IF SCL_toggle='0' THEN
                        state <= WB_ACK1;
                    ELSIF SCL_toggle='1'THEN
                        state <= WB_ACK0;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN WB_ACK1 =>                 -- ACK is stable
                	IF SDA_in = '0' THEN
     					state <= WB_ACK2;
     				ELSIF SDA_in = '1' THEN
     					state <= WB_NACK;
     				ELSE
     					state <= INIT;
     				END IF;
     
     			WHEN WB_ACK2 =>                 -- ACKED
     			    IF SCL_toggle='0' THEN
                        state <= WB_ACK2;
                	ELSIF (SCL_toggle='1' AND bit_send='0')  THEN
                        state <= WR1;
                    ELSIF (SCL_toggle='1' AND bit_send='1') THEN
                        state <= WR5;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN WB_NACK =>
     				IF SCL_toggle='1' THEN
                        state <= STOP1;
                    ELSIF SCL_toggle='0'THEN
                        state <= WB_NACK;
                    ELSE
                        state <= INIT;
                    END IF;
     
          --
          -- READING DATA FROM THE SLAVE
          --
          WHEN EVEN_RD0 =>                     -- Start reading of bit
              IF SCL_toggle = '0' THEN
                  state <= EVEN_RD1;
              ELSIF SCL_toggle = '1' THEN
                  state <= EVEN_RD0;
              ELSE
					          state <= INIT;
              END IF;

          WHEN EVEN_RD1 =>                     -- Bit from slave is stable
              IF SDA_in = '0' THEN
                  state <= EVEN_RD2;
              ELSIF SDA_in = '1' THEN
                  state <= ODD_RD3;
              ELSE
					          state <= INIT;
              END IF;

          WHEN EVEN_RD2 =>                     -- Bit read is 0 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= EVEN_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= EVEN_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= EVEN_RD2;
              ELSE
					          state <= INIT;
              END IF;

          WHEN EVEN_RD3 =>                     -- Bit read is 1 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= EVEN_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= EVEN_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= EVEN_RD3;
              ELSE
					          state <= INIT;
              END IF;

           -- ODD States
           WHEN ODD_RD0 =>                     -- Start reading of bit
              IF SCL_toggle = '0' THEN
                  state <= ODD_RD1;
              ELSIF SCL_toggle = '1' THEN
                  state <= ODD_RD0;
              ELSE
                  state <= INIT;
              END IF;

          WHEN ODD_RD1 =>                     -- Bit from slave is stable
              IF SDA_in = '0' THEN
                  state <= ODD_RD2;
              ELSIF SDA_in = '1' THEN
                  state <= EVEN_RD3;
              ELSE
                  state <= INIT;
              END IF;

          WHEN ODD_RD2 =>                     -- Bit read is 0 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= ODD_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= ODD_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= ODD_RD2;
              ELSE
                  state <= INIT;
              END IF;

          WHEN ODD_RD3 =>                     -- Bit read is 1 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= ODD_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= ODD_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= ODD_RD3;
              ELSE
                  state <= INIT;
              END IF;

          --
          -- WRITING DATA TO THE SLAVE
          --
          WHEN WR0 =>                     -- Sending 0 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= WR2;
              ELSIF SCL_toggle='1'THEN
                  state <= WR0;
              ELSE
                  state <= INIT;
              END IF;
          
          WHEN WR1 =>                     -- Ready to send 0
              state <= WR0;
          
          WHEN WR2 =>                     -- Sent 0 data bit
              state <= WR3;
          
          WHEN WR3 =>                     -- Pulse wait after sending 0
              IF (SCL_toggle='1' AND byte_done='0' AND bit_send='0') THEN
                  state <= WR0;
              ELSIF (SCL_toggle='1' AND byte_done='0' AND bit_send='1')  THEN
                  state <= WR4;
                  
              ELSIF SCL_toggle='0' THEN
                  state <= WR3;

              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='0') THEN
                  state <= WR_L0;
              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='1')  THEN
                  state <= WR_L4;
              ELSE                 
                  state <= INIT;
              END IF;
              
          WHEN WR4 =>                     -- Ready to send 1
              state <= WR5;
              
          WHEN WR5 =>                     -- Sending 1 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= WR6;
              ELSIF SCL_toggle='1'THEN
                  state <= WR5;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN WR6 =>                     -- Sent 1 data bit
              state <= WR7;
          
          WHEN WR7 =>                     -- Pulse wait after sending 1
              IF (SCL_toggle='1' AND byte_done='0' AND bit_send='0') THEN
                  state <= WR1;
              ELSIF (SCL_toggle='1' AND byte_done='0' AND bit_send='1')  THEN
                  state <= WR5;
                  
              ELSIF SCL_toggle='0' THEN
                  state <= WR7;
                  
              
              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='0') THEN
                  state <= WR_L1;
              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='1')  THEN
                  state <= WR_L5;
      
              ELSE                 
                  state <= INIT;
              END IF;

                                --
          -- WRITING LAST BIT
          --    
          WHEN WR_L0 =>                   -- Sending last 0 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= WR_L2;
              ELSIF SCL_toggle='1'THEN
                  state <= WR_L0;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN WR_L1 =>                   -- Ready to send last 0
              state <= WR_L0;
         
          WHEN WR_L2 =>                   -- Sent last 0
              state <= WR_L3;
              
          WHEN WR_L3 =>                   -- Pulse wait after sending last 0
              IF SCL_toggle='1' THEN
                  state <= WR_ACK0;
              ELSIF SCL_toggle='0' THEN
                  state <= WR_L3;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN WR_L4 =>                   -- Ready to send last 1
              state <= WR_L5;
              
          WHEN WR_L5 =>                   -- Sending last 1 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= WR_L6;
              ELSIF SCL_toggle='1'THEN
                  state <= WR_L5;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN WR_L6 =>                   -- Sent last 1
              state <= WR_L7;
              
          WHEN WR_L7 =>                   -- Pulse wait after sending last 1
              IF SCL_toggle='1' THEN
                  state <= WR_ACK0;
              ELSIF SCL_toggle='0' THEN
                  state <= WR_L7;
              ELSE
                  state <= INIT;
              END IF;
                  
                --
                -- ACKING THE TRANSMISSION           
                --
          WHEN WR_ACK0 =>                 -- SDA disabled => waiting for slave
                    IF SCL_toggle='0' THEN
                        state <= WR_ACK1;
                    ELSIF SCL_toggle='1'THEN
                        state <= WR_ACK0;
                    ELSE
                        state <= INIT;
                    END IF;
                    
          WHEN WR_ACK1 =>                 -- Slave's ACK stable
                    IF SDA_in='0' THEN
                        state <= WR_ACK2;
            ELSIF SDA_in='1' THEN
              state <= WR_NACK;
                    -- THIS IS ALSO WHERE WE HAVE TO BRANCH FOR NACKS
                    ELSE
                        state <= INIT;
                    END IF;
          WHEN WR_ACK2 =>                 -- ACKED
                    IF SCL_toggle='0' THEN
                        state <= WR_ACK2;
                    ELSIF (SCL_toggle='1' AND bit_send='0' AND start='1') THEN
                        state <= WR1;
                    ELSIF (SCL_toggle='1' AND bit_send='1' AND start='1') THEN
                        state <= WR5;
                    ELSIF start='0' THEN
                        state <= STOP1;
                    ELSE
                        state <= INIT;
                    END IF;  
     
          WHEN WR_NACK =>
                    IF SCL_toggle='0' THEN
                        state <= WR_NACK;
                    ELSIF (SCL_toggle='1' AND bit_send='0') THEN
                        state <= RE_WR1;                    
                    ELSIF (SCL_toggle='1' AND bit_send='1') THEN
                        state <= RE_WR5;
                    ELSE
                        state <= INIT;
                    END IF;
        
        -- RETRANSMISSION OF DATA TO SLAVE
         WHEN RE_WR0 =>                     -- Sending 0 => pull SDA
                    IF SCL_toggle='0' THEN
                        state <= RE_WR2;
                    ELSIF SCL_toggle='1'THEN
                        state <= RE_WR0;
                    ELSE
                        state <= INIT;
                    END IF;
                
          WHEN RE_WR1 =>                     -- Ready to send 0
              state <= RE_WR0;
          
          WHEN RE_WR2 =>                     -- Sent 0 data bit
              state <= RE_WR3;
          
          WHEN RE_WR3 =>                     -- Pulse wait after sending 0
              IF (SCL_toggle='1' AND byte_done='0' AND bit_send='0') THEN
                  state <= RE_WR0;
              ELSIF (SCL_toggle='1' AND byte_done='0' AND bit_send='1')  THEN
                  state <= RE_WR4;
                  
              ELSIF SCL_toggle='0' THEN
                  state <= RE_WR3;

              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='0') THEN
                  state <= RE_WR_L0;
              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='1')  THEN
                  state <= RE_WR_L4;
              ELSE                 
                  state <= INIT;
              END IF;
              
          WHEN RE_WR4 =>                     -- Ready to send 1
              state <= RE_WR5;
              
          WHEN RE_WR5 =>                     -- Sending 1 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= RE_WR6;
              ELSIF SCL_toggle='1'THEN
                  state <= RE_WR5;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN RE_WR6 =>                     -- Sent 1 data bit
              state <= RE_WR7;
          
          WHEN RE_WR7 =>                     -- Pulse wait after sending 1
              IF (SCL_toggle='1' AND byte_done='0' AND bit_send='0') THEN
                  state <= RE_WR1;
              ELSIF (SCL_toggle='1' AND byte_done='0' AND bit_send='1')  THEN
                  state <= RE_WR5;
                  
              ELSIF SCL_toggle='0' THEN
                  state <= RE_WR7;
                  
              
              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='0') THEN
                  state <= RE_WR_L1;
              ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send='1')  THEN
                  state <= RE_WR_L5;
      
              ELSE                 
                  state <= INIT;
              END IF;

                          --
          -- RE_WRITING LAST BIT
          --    
          WHEN RE_WR_L0 =>                   -- Sending last 0 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= RE_WR_L2;
              ELSIF SCL_toggle='1'THEN
                  state <= RE_WR_L0;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN RE_WR_L1 =>                   -- Ready to send last 0
              state <= RE_WR_L0;
         
          WHEN RE_WR_L2 =>                   -- Sent last 0
              state <= RE_WR_L3;
              
          WHEN RE_WR_L3 =>                   -- Pulse wait after sending last 0
              IF SCL_toggle='1' THEN
                  state <= RE_WR_ACK0;
              ELSIF SCL_toggle='0' THEN
                  state <= RE_WR_L3;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN RE_WR_L4 =>                   -- Ready to send last 1
              state <= RE_WR_L5;
              
          WHEN RE_WR_L5 =>                   -- Sending last 1 => pull SDA
              IF SCL_toggle='0' THEN
                  state <= RE_WR_L6;
              ELSIF SCL_toggle='1'THEN
                  state <= RE_WR_L5;
              ELSE
                  state <= INIT;
              END IF;
              
          WHEN RE_WR_L6 =>                   -- Sent last 1
              state <= RE_WR_L7;
              
          WHEN RE_WR_L7 =>                   -- Pulse wait after sending last 1
              IF SCL_toggle='1' THEN
                  state <= RE_WR_ACK0;
              ELSIF SCL_toggle='0' THEN
                  state <= RE_WR_L7;
              ELSE
                  state <= INIT;
              END IF;
                  
                --
                -- ACKING THE TRANSMISSION           
                --
          WHEN RE_WR_ACK0 =>                 -- SDA disabled => waiting for slave
                    IF SCL_toggle='0' THEN
                        state <= RE_WR_ACK1;
                    ELSIF SCL_toggle='1'THEN
                        state <= RE_WR_ACK0;
                    ELSE
                        state <= INIT;
                    END IF;
                    
          WHEN RE_WR_ACK1 =>                 -- Slave's ACK stable
                    IF SDA_in='0' THEN
                        state <= RE_WR_ACK2;
            ELSIF SDA_in='1' THEN
              state <= RE_WR_NACK;
                    -- THIS IS ALSO WHERE WE HAVE TO BRANCH FOR NACKS
                    ELSE
                        state <= INIT;
                    END IF;
          WHEN RE_WR_ACK2 =>                 -- ACKED
                    IF SCL_toggle='0' THEN
                        state <= RE_WR_ACK2;
                    ELSIF (SCL_toggle='1' AND bit_send='0' AND start='1') THEN
                        state <= WR1;
                    ELSIF (SCL_toggle='1' AND bit_send='1' AND start='1') THEN
                        state <= WR5;
                    ELSIF start='0' THEN
                        state <= STOP1;
                    ELSE
                        state <= INIT;
                    END IF;  
     
          WHEN RE_WR_NACK =>
                    IF SCL_toggle='0' THEN
                        state <= RE_WR_NACK;
                    ELSIF SCL_toggle='1' THEN
                        state <= STOP1;
                    ELSE
                        state <= INIT;
                    END IF;

                --
                -- READING LAST BIT
                -- 

                -- Last bit from the even states
          WHEN EVEN_RD_L0 =>                   -- Start reading of last bit
              IF SCL_toggle = '0' THEN
                  state <= EVEN_RD_L1;
              ELSIF SCL_toggle = '1' THEN
                  state <= EVEN_RD_L0;
              ELSE
					          state <= INIT;
              END IF;

          WHEN EVEN_RD_L1 =>                   -- Last bit from slave stable
              IF SDA_in = '0' THEN
                  state <= EVEN_RD_L2;
              ELSIF SDA_in = '1' THEN
                  state <= EVEN_RD_L3;
              ELSE
					state <= INIT;
              END IF;

          WHEN EVEN_RD_L2 =>                   -- Last bit read is 0
              IF SCL_toggle = '1' THEN
                  state <= RD_NACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= EVEN_RD_L2;
              ELSE
					          state <= INIT;
              END IF;      

          WHEN EVEN_RD_L3 =>                   -- Last bit read is 1
              IF SCL_toggle = '1' THEN
                  state <= RD_ACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= EVEN_RD_L3;
              ELSE
					          state <= INIT;
              END IF;

          -- LAst bit from the ODD states

           WHEN ODD_RD_L0 =>                   -- Start reading of last bit
              IF SCL_toggle = '0' THEN
                  state <= ODD_RD_L1;
              ELSIF SCL_toggle = '1' THEN
                  state <= ODD_RD_L0;
              ELSE
                  state <= INIT;
              END IF;

          WHEN ODD_RD_L1 =>                   -- Last bit from slave stable
              IF SDA_in = '0' THEN
                  state <= ODD_RD_L2;
              ELSIF SDA_in = '1' THEN
                  state <= ODD_RD_L3;
              ELSE
                  state <= INIT;
              END IF;

          WHEN ODD_RD_L2 =>                   -- Last bit read is 0
              IF SCL_toggle = '1' THEN
                  state <= RD_ACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= ODD_RD_L2;
              ELSE
                  state <= INIT;
              END IF;      

          WHEN ODD_RD_L3 =>                   -- Last bit read is 1
              IF SCL_toggle = '1' THEN
                  state <= RD_NACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= ODD_RD_L3;
              ELSE
                  state <= INIT;
              END IF;
     
                
          WHEN RD_ACK0 =>                 -- Ready to send the ACK
              state <= RD_ACK1;
     
     			WHEN RD_ACK1 =>                 -- Sending the ACK => SDA pull
                    IF SCL_toggle='0' THEN
                        state <= RD_ACK2;
                    ELSIF SCL_toggle='1' THEN
                        state <= RD_ACK1;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN RD_ACK2 =>                 -- ACK is stable
                	state <= RD_ACK3;
     
     			WHEN RD_ACK3 =>                 -- Pulse wait after writing the ACK
                    IF (SCL_toggle='1' and start='1') THEN
                        state <= EVEN_RD0;
                    ELSIF (CL_toggle='1' and start='0') THEN
                        state <= STOP0;
                    ELSIF SCL_toggle='0' THEN
                        state <= RD_ACK3;
                    ELSE
                        state <= INIT;
                    END IF;

          WHEN RD_NACK0 =>                 -- Ready to send the ACK
              state <= RD_NACK1;
     
          WHEN RD_NACK1 =>                 -- Sending the ACK => SDA pull
                    IF SCL_toggle='0' THEN
                        state <= RD_NACK2;
                    ELSIF SCL_toggle='1' THEN
                        state <= RD_NACK1;
                    ELSE
                        state <= INIT;
                    END IF;
     
          WHEN RD_NACK2 =>                 -- ACK is stable
                  state <= RD_NACK3;
     
          WHEN RD_NACK3 =>                 -- Pulse wait after writing the ACK
                    IF SCL_toggle='1' THEN
                        state <= RE_EVEN_RD0;
                    ELSIF SCL_toggle='0' THEN
                        state <= RD_NACK3;
                    ELSE
                        state <= INIT;
                    END IF;

          --
          -- RETRANSMISION
          --
          -- Last bit from the even states
                   WHEN RE_EVEN_RD0 =>                     -- Start reading of bit
              IF SCL_toggle = '0' THEN
                  state <= RE_EVEN_RD1;
              ELSIF SCL_toggle = '1' THEN
                  state <= RE_EVEN_RD0;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_EVEN_RD1 =>                     -- Bit from slave is stable
              IF SDA_in = '0' THEN
                  state <= RE_EVEN_RD2;
              ELSIF SDA_in = '1' THEN
                  state <= RE_ODD_RD3;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_EVEN_RD2 =>                     -- Bit read is 0 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= RE_EVEN_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= RE_EVEN_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_EVEN_RD2;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_EVEN_RD3 =>                     -- Bit read is 1 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= RE_EVEN_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= RE_EVEN_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_EVEN_RD3;
              ELSE
                  state <= INIT;
              END IF;

           -- RE_ODD States
           WHEN RE_ODD_RD0 =>                     -- Start reading of bit
              IF SCL_toggle = '0' THEN
                  state <= RE_ODD_RD1;
              ELSIF SCL_toggle = '1' THEN
                  state <= RE_ODD_RD0;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_ODD_RD1 =>                     -- Bit from slave is stable
              IF SDA_in = '0' THEN
                  state <= RE_ODD_RD2;
              ELSIF SDA_in = '1' THEN
                  state <= RE_EVEN_RD3;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_ODD_RD2 =>                     -- Bit read is 0 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= RE_ODD_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= RE_ODD_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_ODD_RD2;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_ODD_RD3 =>                     -- Bit read is 1 data bit
              IF SCL_toggle = '1' THEN
                  IF byte_done = '0' THEN
                      state <= RE_ODD_RD0;
                  ELSIF byte_done = '1' THEN
                      state <= RE_ODD_RD_L0;
                  END IF;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_ODD_RD3;
              ELSE
                  state <= INIT;
              END IF;



          WHEN RE_EVEN_RD_L0 =>                   -- Start reading of last bit
              IF SCL_toggle = '0' THEN
                  state <= RE_EVEN_RD_L1;
              ELSIF SCL_toggle = '1' THEN
                  state <= RE_EVEN_RD_L0;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_EVEN_RD_L1 =>                   -- Last bit from slave stable
              IF SDA_in = '0' THEN
                  state <= RE_EVEN_RD_L2;
              ELSIF SDA_in = '1' THEN
                  state <= RE_EVEN_RD_L3;
              ELSE
        state <= INIT;
              END IF;

          WHEN RE_EVEN_RD_L2 =>                   -- Last bit read is 0
              IF SCL_toggle = '1' THEN
                  state <= RE_RD_NACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_EVEN_RD_L2;
              ELSE
                  state <= INIT;
              END IF;      

          WHEN RE_EVEN_RD_L3 =>                   -- Last bit read is 1
              IF SCL_toggle = '1' THEN
                  state <= RE_RD_ACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_EVEN_RD_L3;
              ELSE
                  state <= INIT;
              END IF;

          -- LAst bit from the RE_ODD states

           WHEN RE_ODD_RD_L0 =>                   -- Start reading of last bit
              IF SCL_toggle = '0' THEN
                  state <= RE_ODD_RD_L1;
              ELSIF SCL_toggle = '1' THEN
                  state <= RE_ODD_RD_L0;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_ODD_RD_L1 =>                   -- Last bit from slave stable
              IF SDA_in = '0' THEN
                  state <= RE_ODD_RD_L2;
              ELSIF SDA_in = '1' THEN
                  state <= RE_ODD_RD_L3;
              ELSE
                  state <= INIT;
              END IF;

          WHEN RE_ODD_RD_L2 =>                   -- Last bit read is 0
              IF SCL_toggle = '1' THEN
                  state <= RE_RD_ACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_ODD_RD_L2;
              ELSE
                  state <= INIT;
              END IF;      

          WHEN RE_ODD_RD_L3 =>                   -- Last bit read is 1
              IF SCL_toggle = '1' THEN
                  state <= RE_RD_NACK0;
              ELSIF SCL_toggle = '0' THEN
                  state <= RE_ODD_RD_L3;
              ELSE
                  state <= INIT;
              END IF;

              WHEN RE_RD_ACK0 =>                 -- Ready to send the ACK
              state <= RE_RD_ACK1;
     
          WHEN RE_RD_ACK1 =>                 -- Sending the ACK => SDA pull
                    IF SCL_toggle='0' THEN
                        state <= RE_RD_ACK2;
                    ELSIF SCL_toggle='1' THEN
                        state <= RE_RD_ACK1;
                    ELSE
                        state <= INIT;
                    END IF;
     
          WHEN RE_RD_ACK2 =>                 -- ACK is stable
                  state <= RE_RD_ACK3;
     
          WHEN RE_RD_ACK3 =>                 -- Pulse wait after writing the ACK
                    IF (SCL_toggle='1' and start='1') THEN
                        state <= EVEN_RD0;
                    ELSIF (CL_toggle='1' and start='0') THEN
                        state <= STOP0;
                    ELSIF SCL_toggle='0' THEN
                        state <= RE_RD_ACK3;
                    ELSE
                        state <= INIT;
                    END IF;

          WHEN RE_RD_NACK0 =>                 -- Ready to send the ACK
              state <= RE_RD_NACK1;
     
          WHEN RE_RD_NACK1 =>                 -- Sending the ACK => SDA pull
                    IF SCL_toggle='0' THEN
                        state <= RE_RD_NACK2;
                    ELSIF SCL_toggle='1' THEN
                        state <= RE_RD_NACK1;
                    ELSE
                        state <= INIT;
                    END IF;
     
          WHEN RE_RD_NACK2 =>                 -- ACK is stable
                  state <= RE_RD_NACK3;
     
          WHEN RE_RD_NACK3 =>                 -- Pulse wait after writing the ACK
                    IF SCL_toggle='1' THEN
                        state <= STOP0;
                    ELSIF SCL_toggle='0' THEN
                        state <= RE_RD_NACK3;
                    ELSE
                        state <= INIT;
                    END IF;
     
-- STOP STATES HERE
     			WHEN STOP0 =>
                    IF SCL_toggle='0' THEN
                        state <= STOP2;
                    ELSIF SCL_toggle='1' THEN
                        state <= STOP0;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN STOP1 =>
     				IF SCL_toggle='0' THEN
                        state <= STOP2;
                    ELSIF SCL_toggle='1' THEN
                        state <= STOP1;
                    ELSE
                        state <= INIT;
                    END IF;
     
     			WHEN STOP2 =>
     				state <= STOP3;
     
     			WHEN STOP3 =>
     				IF SCL_toggle='0' THEN
                        state <= STOP3;
                    ELSIF SCL_toggle='1' THEN
                        state <= INIT;
                    ELSE
                        state <= INIT;
                    END IF;
  
     			END CASE;
     	ELSE
     		-- DO NOTHING?
     	END IF;
    END PROCESS;
    
    --------------------------------------------------------
    ----------------------- OUTPUTS ------------------------
    --------------------------------------------------------
    
-----------------
    -- OUTPUT SCL_OUT
    -----------------
SCL_out 		<= '1' WHEN
     ( state=INIT 			OR
       state=ST1 			OR
       state=ST2 			OR
       
       state=ADDR1 			OR
       state=ADDR2 			OR
       state=ADDR7 			OR
       state=ADDR6 			OR
       
       state=RB2 			OR
       state=RB3 			OR
       state=WB2 			OR
       state=WB3 			OR
       
       state=RB_ACK1 		OR
       state=RB_ACK2 		OR
       state=RB_NACK        OR
       
       state=WB_ACK1 		OR
       state=WB_ACK2 		OR
       state=WB_NACK        OR
       
       state=EVEN_RD1 			OR
       state=EVEN_RD2 			OR
       state=EVEN_RD3 			OR

       state=ODD_RD1       OR
       state=ODD_RD2      OR
       state=ODD_RD3      OR

       state=RE_EVEN_RD1      OR
       state=RE_EVEN_RD2       OR
       state=RE_EVEN_RD3       OR

       state=RE_ODD_RD1       OR
       state=RE_ODD_RD2      OR
       state=RE_ODD_RD3      OR


       state=WR2 			OR
       state=WR3 			OR
       state=WR6 			OR
       state=WR7 			OR

       state=RE_WR2       OR
       state=RE_WR3      OR
       state=RE_WR6      OR
       state=RE_WR7      OR
       
       state=EVEN_RD_L1 			OR
       state=EVEN_RD_L2 			OR
       state=EVEN_RD_L3 			OR

       state=ODD_RD_L1       OR
       state=ODD_RD_L2      OR
       state=ODD_RD_L3      OR

       state=RE_EVEN_RD_L1      OR
       state=RE_EVEN_RD_L2       OR
       state=RE_EVEN_RD_L3       OR

       state=RE_ODD_RD_L1       OR
       state=RE_ODD_RD_L2      OR
       state=RE_ODD_RD_L3      OR
       
       state=WR_L2 			OR  
       state=WR_L3 			OR
       state=WR_L6 			OR
       state=WR_L7 			OR

       state=RE_WR_L2       OR  
       state=RE_WR_L3      OR
       state=RE_WR_L6      OR
       state=RE_WR_L7      OR
       
       state=RD_ACK2 		OR
       state=RD_ACK3 		OR
       
       state=RE_RD_ACK2     OR
       state=RE_RD_ACK3    OR

       state=WR_ACK1 		OR  
       state=WR_ACK2 		OR
       state=WR_NACK     OR

       state=RE_WR_ACK1    OR  
       state=RE_WR_ACK2    OR
       state=RE_WR_NACK     OR
       
       state=STOP2			OR
       state=STOP3)
     ELSE '0';
     
    --------------------
    -- OUTPUT SCL_ENABLE
    --------------------
SCL_enable 		<= '0' WHEN state=INIT ELSE '1';
    
    -----------------
    -- OUTPUT SDA_out
    -----------------
    SDA_out 		<= '0' WHEN 
     (state=ST2 			OR
      state=ADDR0 			OR
      state=ADDR1 			OR
      state=ADDR2 			OR
      state=ADDR4 			OR
      
      state=RB1 			OR

      state=WB1             OR
      state=WB2 			OR
      state=WB3 			OR
      
      state=WR0 			OR
      state=WR2 			OR
      state=WR3 			OR
      state=WR4 			OR
       
      state=WR_L0 			OR
      state=WR_L2 			OR
      state=WR_L3 			OR
      state=WR_L4 			OR

      state=RE_WR_L0       OR
      state=RE_WR_L2       OR
      state=RE_WR_L3       OR
      state=RE_WR_L4       OR
       
      state=RD_ACK1 		OR
      state=RD_ACK2 		OR
      state=RD_ACK3 		OR

      state=RE_RD_ACK1     OR
      state=RE_RD_ACK2     OR
      state=RE_RD_ACK3     OR

       
      state=STOP0			OR
      state=STOP2)
     ELSE '1';

    ---------------------
    -- OUTPUT SDA_ENABLE
    ---------------------
    SDA_enable 		<= '0' WHEN
     ( state=INIT 			OR
       
       state=RB_ACK0		OR
       state=RB_ACK1		OR
       state=RB_ACK2		OR
       state=RB_NACK        OR
       
       state=WB_ACK0		OR
       state=WB_ACK1		OR
       state=WB_ACK2		OR
       state=WB_NACK        OR
       
       state=EVEN_RD0			OR
       state=EVEN_RD1			OR
       state=EVEN_RD2			OR
       state=EVEN_RD3			OR

       state=ODD_RD0     OR
       state=ODD_RD1     OR
       state=ODD_RD2     OR
       state=ODD_RD3     OR

       state=RE_EVEN_RD0     OR
       state=RE_EVEN_RD1     OR
       state=RE_EVEN_RD2     OR
       state=RE_EVEN_RD3     OR

       state=RE_ODD_RD0     OR
       state=RE_ODD_RD1     OR
       state=RE_ODD_RD2     OR
       state=RE_ODD_RD3     OR
       
       state=EVEN_RD_L0			OR
       state=EVEN_RD_L1			OR
       state=EVEN_RD_L2			OR
       state=EVEN_RD_L3			OR

       state=ODD_RD_L0     OR
       state=ODD_RD_L1     OR
       state=ODD_RD_L2     OR
       state=ODD_RD_L3     OR

       state=RE_EVEN_RD_L0     OR
       state=RE_VEN_RD_L1     OR
       state=RE_EVEN_RD_L2     OR
       state=RE_EVEN_RD_L3     OR

       state=RE_ODD_RD_L0     OR
       state=RE_ODD_RD_L1     OR
       state=RE_ODD_RD_L2     OR
       state=RE_ODD_RD_L3     OR
       
       state=RD_ACK0		OR
       state=RE_RD_ACK0    OR
       
       state=WR_ACK0		OR
       state=WR_ACK1		OR
       state=WR_ACK2		OR
       state=WR_NACK    OR

       state=RE_WR_ACK0    OR
       state=RE_WR_ACK1    OR
       state=RE_WR_ACK2    OR
       state=RE_WR_NACK    OR
       
     
       state=STOP1)
     ELSE '1';
     
    ----------------------- 
    -- OUTPUT DATA_RECEIVED
    -----------------------
    data_received 	<= '0' WHEN
     (state=EVEN_RD2 			OR
      state=ODD_RD2      OR
      state=RE_EVEN_RD2      OR
      state=RE_ODD_RD2      OR

      state=EVEN_RD_L2			OR
      state=ODD_RD_L2      OR
      state=RE_EVEN_RD_L2      OR
      state=RE_ODD_RD_L2)
     ELSE '1';

    --------------------
    -- OUTPUT CNT_ENABLE
    --------------------
    cnt_enable 		<= '1' WHEN
      (state=ST2 			OR
    
       state=ADDR2 			OR
       state=ADDR7 			OR
       
       state=RB3 			OR
       state=WB3 			OR
       
       state=RB_ACK2 		OR
       state=RB_NACK        OR
       
       state=WB_ACK2 		OR
       state=WB_NACK        OR
       
       state=EVEN_RD2 			OR
       state=EVEN_RD3 			OR
       state=ODD_RD2       OR
       state=ODD_RD3       OR

       state=RE_EVEN_RD2       OR
       state=RE_EVEN_RD3       OR
       state=RE_ODD_RD2       OR
       state=RE_ODD_RD3       OR
        
       state=WR3 			OR
       state=WR7 			OR

       state=RE_WR3      OR
       state=RE_WR7      OR
       
       state=EVEN_RD_L2 			OR
       state=EVEN_RD_L3 			OR
       state=ODD_RD_L2       OR
       state=ODD_RD_L3       OR

       state=RE_EVEN_RD_L2       OR
       state=RE_EVEN_RD_L3       OR
       state=RE_ODD_RD_L2       OR
       state=RE_ODD_RD_L3       OR
        
       state=WR_L3 			OR
       state=WR_L7 			OR

       state=RE_WR_L3      OR
       state=RE_WR_L7      OR
       
       state=RD_ACK3 		OR
       state=WR_ACK2 		OR
       state=WR_NACK    OR

       state=RE_RD_ACK3    OR
       state=RE_WR_ACK2    OR
       state=RE_WR_NACK    OR
        
       
       state=STOP3)
     ELSE '0';
       
END ArchMCFSMv2;