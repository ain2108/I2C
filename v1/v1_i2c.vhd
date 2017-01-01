LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY MasterControllerFSM is
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
END MasterControllerFSM;


ARCHITECTURE ArchMCFSM of MasterControllerFSM is
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
      RBD0,                    -- Sending READ(1), pull SDA
      RBD1,                    -- Ready to send READ(1)
      RBD2,                    -- Sent READ(1)
      RBD3,                    -- Pulse wait after READ(1)
      
      WBR0,                    -- Ready to send WRITE(0)
      WBR1,                    -- Sending WRITE(0), pull SDA
      WBR2,                    -- Sent WRITE(0)
      WBR3,                    -- Pulse wait after WRITE(0)
      
      -- Acking the address transmission
      RB_ACK0,                 -- Slave can send the ACK
      RB_ACK1,                 -- ACK is stable
      RB_ACK2,                 -- ACKED
      
      WB_ACK0,                 -- Slave can send the ACK
      WB_ACK1,                 -- ACK is stable
      WB_ACK2,                 -- ACKED
      
      -- Reading data from the slave
      RD0,                     -- Start reading of bit
      RD1,                     -- Bit from slave is stable
      RD2,                     -- Bit read is 0 data bit
      RD3,                     -- Bit read is 1 data bit
      
      
      -- Writing data to slave
      WR0,                     -- Sending 0, pull SDA
      WR1,                     -- Ready to send 0
      WR2,                     -- Sent 0 data bit
      WR3,                     -- Pulse wait after sending 0
      WR4,                     -- Ready to send 1
      WR5,                     -- Sending 1, pull SDA
      WR6,                     -- Sent 1 data bit
      WR7,                     -- Pulse wait after sending 1
      
      -- Reading the last bit
      RD_L0,                   -- Start reading of last bit
      RD_L1,                   -- Last bit from slave stable
      RD_L2,                   -- Last bit read is 0
      RD_L3,                   -- Last bit read is 1
      
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
      
      -- Writing the ACK to the slave
      RD_ACK0,                 -- Ready to send the ACK
      RD_ACK1,                 -- Sending the ACK, SDA pull
      RD_ACK2,                 -- ACK is stable
      RD_ACK3,                 -- Pulse wait after writing the ACK
      
      -- Stop signal received, reading the last bit
      STOP_RD0,                -- Start reading of last bit in STOP
      STOP_RD1,                -- Last bit from slave stable in STOP
      STOP_RD2,                -- Last bit read is 0 in STOP
      STOP_RD3,                -- Last bit read is 1 in STOP
      
      -- Stop signal received, writing the last bit and ACKING
      STOP_WR0,                -- Sending last 0, pull SDA in STOP
      STOP_WR1,                -- Ready to send last 0 in STOP
      STOP_WR2,                -- Sent last 0 in STOP
      STOP_WR3,                -- Pulse wait after sending last 0 in STOP
      STOP_WR4,                -- Ready to send last 1 in STOP
      STOP_WR5,                -- Sending last 1, pull SDA in STOP
      STOP_WR6,                -- Sent last 1 in STOP
      STOP_WR7,                -- Pulse wait after sending last 1 in STOP
      
      -- Stop signal received, ACK the last byte
      STOP_RD_ACK0,            -- Ready to send the ACK in STOP
      STOP_RD_ACK1,            -- Sending the ACK, SDA pull in STOP
      STOP_RD_ACK2,            -- ACK is stable in STOP
      STOP_RD_ACK3,            -- Pulse wait after writing the ACK in STOP
      
      -- Stop signal received, receive the ACK for the last byte sent
      STOP_WR_ACK0,            -- SDA disabled, waiting for slave in STOP
      STOP_WR_ACK1,            -- Slave's ACK stable in STOP
      STOP_WR_ACK2);           -- ACKED in STOP

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
                    ELSE
                        state <= ST2;
                    END IF;
                
                --
                -- SEND SLAVE ADDRESS
                --    
                WHEN ADDR0 =>                  -- Sending 0 addr bit => pull SDA 
                    IF SCL_toggle = '0' THEN
                        state <= ADDR1;
                    ELSE
                        state <= ADDR0;
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
                    ELSE
                        state <= ADDR2;
                    END IF;
                    
                WHEN ADDR3 =>                  -- Ready to send 0 addr bit
                    state <= ADDR0;
                    
                WHEN ADDR4 =>                  -- Readt to send 1 addr bit
                    state <= ADDR5;
                    
                WHEN ADDR5 =>                  -- Sending 1 bit => pull SDA
                    IF SCL_toggle = '0' THEN
                        state <= ADDR6;
                    ELSE
                        state <= ADDR5;
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
                    ELSE
                        state <= ADDR7;
                    END IF;
                    
                WHEN RBD0 =>                    -- Sending READ(1) => pull SDA
                WHEN RBD1 =>                    -- Ready to send READ(1)
                WHEN RBD2 =>                    -- Sent READ(1)
                WHEN RBD3 =>                    -- Pulse wait after READ(1)
                WHEN WBR0 =>                    -- Ready to send WRITE(0)
                WHEN WBR1 =>                    -- Sending WRITE(0) => pull SDA
                WHEN WBR2 =>                    -- Sent WRITE(0)
                WHEN WBR3 =>                    -- Pulse wait after WRITE(0)
                WHEN RB_ACK0 =>                 -- Slave can send the ACK
                WHEN RB_ACK1 =>                 -- ACK is stable
                WHEN RB_ACK2 =>                 -- ACKED
                WHEN WB_ACK0 =>                 -- Slave can send the ACK
                WHEN WB_ACK1 =>                 -- ACK is stable
                WHEN WB_ACK2 =>                 -- ACKED
                
                --
                -- READING DATA FROM THE SLAVE
                --
                WHEN RD0 =>                     -- Start reading of bit
                    IF SCL_toggle = '0' THEN
                        state <= RD1;
                    ELSE
                        state <= RD0;
                    END IF;
                
                WHEN RD1 =>                     -- Bit from slave is stable
                    IF SDA_in = '0' THEN
                        state <= RD2;
                    ELSIF SDA_in = '1' THEN
                        state <= RD3;
                    END IF;
                    
                WHEN RD2 =>                     -- Bit read is 0 data bit
                    IF SCL_toggle = '1' THEN
                        IF byte_done = '0' THEN
                            state <= RD0;
                        ELSIF byte_done = '1' and start = '0' THEN
                            state <= STOP_RD0;
                        ELSIF byte_done = '1' and start = '1' THEN
                            state <= RD_L0;
                        END IF;
                    ELSE
                        state <= RD2;
                    END IF;
                    
                WHEN RD3 =>                     -- Bit read is 1 data bit
                    IF SCL_toggle = '1' THEN
                        IF byte_done = '0' THEN
                            state <= RD0;
                        ELSIF byte_done = '1' and start = '0' THEN
                            state <= STOP_RD0;
                        ELSIF byte_done = '1' and start = '1' THEN
                            state <= RD_L0;
                        END IF;
                    ELSE
                        state <= RD3;
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
                    IF (SCL_toggle='1' AND byte_done='0' AND bit_send=0) THEN
                        state <= WR0;
                    ELSIF (SCL_toggle='1' AND byte_done='0' AND bit_send=1)  THEN
                        state <= WR4;
                        
                    ELSIF SCL_toggle='0' THEN
                        state <= WR3;
                        
                    ELSIF start='0' THEN
                        IF (SCL_toggle='1' AND byte_done='1' AND bit_send=0) THEN
                            state <= STOP_WR0;
                        ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send=1)  THEN
                            state <= STOP_WR4;
                        ELSE
                            state <= INIT;
                        END IF;
                        
                    ELSIF start='1' THEN
                        IF (SCL_toggle='1' AND byte_done='1' AND bit_send=0) THEN
                            state <= WR_L0;
                        ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send=1)  THEN
                            state <= WR_L4;
                        ELSE
                            state <= INIT;
                        END IF;
                    
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
                    IF (SCL_toggle='1' AND byte_done='0' AND bit_send=0) THEN
                        state <= WR1;
                    ELSIF (SCL_toggle='1' AND byte_done='0' AND bit_send=1)  THEN
                        state <= WR5;
                        
                    ELSIF SCL_toggle='0' THEN
                        state <= WR7;
                        
                    ELSIF start='0' THEN
                        IF (SCL_toggle='1' AND byte_done='1' AND bit_send=0) THEN
                            state <= STOP_WR1;
                        ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send=1)  THEN
                            state <= STOP_WR5;
                        ELSE
                            state <= INIT;
                        END IF;
                        
                    ELSIF start='1' THEN
                        IF (SCL_toggle='1' AND byte_done='1' AND bit_send=0) THEN
                            state <= WR_L1;
                        ELSIF (SCL_toggle='1' AND byte_done='1' AND bit_send=1)  THEN
                            state <= WR_L5;
                        ELSE
                            state <= INIT;
                        END IF;
                    
                    ELSE                 
                        state <= INIT;
                    END IF;
                    
                --
                -- READING LAST BIT
                -- 
                WHEN RD_L0 =>                   -- Start reading of last bit
                    IF SCL_toggle = '0' THEN
                        state <= RD_L1;
                    ELSE
                        state <= RD_L0;
                    END IF;
                    
                WHEN RD_L1 =>                   -- Last bit from slave stable
                    IF SDA_in = '0' THEN
                        state <= RD_L2;
                    ELSIF SDA_in = '1' THEN
                        state <= RD_L3;
                    END IF;
                    
                WHEN RD_L2 =>                   -- Last bit read is 0
                    IF SCL_toggle = '1' THEN
                        state <= RD_ACK0;
                    ELSE
                        state <= RD_L2;
                    END IF;
                    
                WHEN RD_L3 =>                   -- Last bit read is 1
                    IF SCL_toggle = '1' THEN
                        state <= RD_ACK0;
                    ELSE
                        state <= RD_L3;
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
                  
                  
                -- ACKING THE TRANSMISSION           
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
                    -- THIS IS ALSO WHERE WE HAVE TO BRANCH FOR NACKS
                    ELSE
                        state <= INIT;
                    END IF;
                WHEN WR_ACK2 =>                 -- ACKED
                    IF SCL_toggle='0' THEN
                        state <= WR_ACK2;
                    ELSIF (SCL_toggle='1' AND bit_send='0') THEN
                        state <= WR0;
                    ELSIF (SCL_toggle='1' AND bit_send='1') THEN
                        state <= WR4;
                    ELSE
                        state <= INIT;
                    END IF;                
                
                WHEN RD_ACK0 =>                 -- Ready to send the ACK
                WHEN RD_ACK1 =>                 -- Sending the ACK => SDA pull
                WHEN RD_ACK2 =>                 -- ACK is stable
                WHEN RD_ACK3 =>                 -- Pulse wait after writing the ACK
                WHEN STOP_RD0 =>                -- Start reading of last bit in STOP
                WHEN STOP_RD1 =>                -- Last bit from slave stable in STOP
                WHEN STOP_RD2 =>                -- Last bit read is 0 in STOP
                WHEN STOP_RD3 =>                -- Last bit read is 1 in STOP
                
                -- STOP SEQUENCE FOR WRITING
                WHEN STOP_WR0 =>                -- Sending last 0 => pull SDA in STOP
                    IF SCL_toggle='0' THEN
                        state <= STOP_WR2;
                    ELSIF SCL_toggle='1'THEN
                        state <= STOP_WR0;
                    ELSE
                        state <= INIT;
                    END IF;
                    
                WHEN STOP_WR1 =>                -- Ready to send last 0 in STOP
                    state <= STOP_WR0;
                    
                WHEN STOP_WR2 =>                -- Sent last 0 in STOP
                    state <= STOP_WR3;
                    
                WHEN STOP_WR3 =>                -- Pulse wait after sending last 0 in STOP
                    IF SCL_toggle='1' THEN
                        state <= STOP_WR_ACK0;
                    ELSIF SCL_toggle='0' THEN
                        state <= STOP_WR3;
                    ELSE
                        state <= INIT;
                    END IF;
                    
                WHEN STOP_WR4 =>                -- Ready to send last 1 in STOP
                    state <= STOP_WR5;
                    
                WHEN STOP_WR5 =>                -- Sending last 1 => pull SDA in STOP
                    IF SCL_toggle='0' THEN
                        state <= STOP_WR6;
                    ELSIF SCL_toggle='1'THEN
                        state <= STOP_WR5;
                    ELSE
                        state <= INIT;
                    END IF;
                    
                WHEN STOP_WR6 =>                -- Sent last 1 in STOP
                    state <= STOP_WR7;
                    
                WHEN STOP_WR7 =>                -- Pulse wait after sending last 1 in STOP
                     IF SCL_toggle='1' THEN
                        state <= STOP_WR_ACK0;
                    ELSIF SCL_toggle='0' THEN
                        state <= STOP_WR7;
                    ELSE
                        state <= INIT;
                    END IF;
                    
                WHEN STOP_RD_ACK0 =>            -- Ready to send the ACK in STOP
                WHEN STOP_RD_ACK1 =>            -- Sending the ACK => SDA pull in STOP
                WHEN STOP_RD_ACK2 =>            -- ACK is stable in STOP
                WHEN STOP_RD_ACK3 =>            -- Pulse wait after writing the ACK in STOP
                
                WHEN STOP_WR_ACK0 =>            -- SDA disabled => waiting for slave in STOP
                    IF SCL_toggle='0' THEN
                        state <= STOP_WR_ACK1;
                    ELSIF SCL_toggle='1'THEN
                        state <= STOP_WR_ACK0;
                    ELSE
                        state <= INIT;
                    END IF;
                    
                WHEN STOP_WR_ACK1 =>            -- Slave's ACK stable in STOP
                    IF SDA_in='0' THEN
                        state <= STOP_WR_ACK2;
                    -- THIS IS ALSO WHERE WE HAVE TO BRANCH FOR NACKS
                    ELSE
                        state <= INIT;
                    END IF;
                    
                WHEN STOP_WR_ACK2 =>             -- ACKED in STOP
                    IF SCL_toggle='0' THEN
                        state <= WR_ACK2;
                    ELSIF SCL_toggle='1' THEN
                        state <= INIT;
                    ELSE
                        state <= INIT;
                    END IF;
                 
