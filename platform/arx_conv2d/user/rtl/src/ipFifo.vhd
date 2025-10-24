--------------------------------------------------------------------------------
--
-- Copyright(c) 2024 Electronics and Telecommunications Research Institute(ETRI)
-- All Rights Reserved.
--
-- Following acts are STRICTLY PROHIBITED except when a specific prior written
-- permission is obtained from ETRI or a separate written agreement with ETRI
-- stipulates such permission specifically:
--   a) Selling, distributing, sublicensing, renting, leasing, transmitting,
--      redistributing or otherwise transferring this software to a third party;
--   b) Copying, transforming, modifying, creating any derivatives of, reverse 
--      engineering, decompiling, disassembling, translating, making any attempt
--      to discover the source code of, the whole or part of this software 
--      in source or binary form;
--   c) Making any copy of the whole or part of this software other than one 
--      copy for backup purposes only; and
--   d) Using the name, trademark or logo of ETRI or the names of contributors 
--      in order to endorse or promote products derived from this software.
--
-- This software is provided "AS IS," without a warranty of any kind.
-- ALL EXPRESS OR IMPLIED CONDITIONS, REPRESENTATIONS AND WARRANTIES, INCLUDING
-- ANY IMPLIED WARRANTY OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE OR
-- NON-INFRINGEMENT,ARE HEREBY EXCLUDED. IN NO EVENT WILL ETRI(OR ITS LICENSORS,
-- IF ANY) BE LIABLE FOR ANY LOST REVENUE, PROFIT OR DATA, OR FOR DIRECT, 
-- INDIRECT, SPECIAL, CONSEQUENTIAL, INCIDENTAL OR PUNITIVE DAMAGES, HOWEVER 
-- CAUSED AND REGARDLESS OF THE THEORY OF LIABILITY, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE USE OF OR INABILITY TO USE THIS SOFTWARE, EVEN IF ETRI 
-- HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
--
-- Any permitted redistribution of this software must retain the copyright 
-- notice, conditions, and disclaimer as specified above.
--
--------------------------------------------------------------------------------
-- Copyright Human Body Communication 2024, All rights reserved.
-- AI Edge SoC Research Section, AI SoC Research Division,
-- Artificial Intelligence Research Laboratory
-- Electronics and Telecommunications Research Institute (ETRI)
--------------------------------------------------------------------------------

--==============================================================================
-- File Name : ipFifo.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V241121    hkim  FIFO IP (Source: ipFifo.vhd, 2002.11.26)
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY ipFifo IS
GENERIC(
  sizeOfWidth     : NATURAL := 8;
  sizeOfDepth     : NATURAL := 8
);
PORT(
  outQ            : out std_logic_vector(sizeOfWidth-1 downto 0);
  inA             : in  std_logic_vector(sizeOfWidth-1 downto 0);
  enable          : in  std_logic;
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF ipFifo IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  TYPE ipFifoType IS ARRAY(0 TO sizeOfDepth-1) OF std_logic_vector(sizeOfWidth-1 downto 0);
  SIGNAL  fifoRegI  : ipFifoType;
  -- SIGNAL END

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  -- END GENERATE

  ------------------------------------------------------------------------------
  -- SIGNAL CONNECTION
  ------------------------------------------------------------------------------
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  -- END MAPPING

  ------------------------------------------------------------------------------
  -- PROCESSES
  ------------------------------------------------------------------------------
  FIFO_BYPASS_GEN0 : IF ( sizeOfDepth = 0 ) GENERATE
    outQ <=inA;
  END GENERATE;

  FIFO_GEN1 : IF ( sizeOfDepth = 1 ) GENERATE -- size of depth = 1
    ipFifoP : PROCESS(resetB, clk)
    BEGIN
      if resetB='0' then outQ <=(others=>'0');
      elsif clk'event and clk='1' then
        if enable='1' then
          outQ <=inA;
        end if;
      end if;
    END PROCESS;
  END GENERATE;

  FIFO_GEN2 : IF ( sizeOfDepth >= 2 ) GENERATE
    ipFifoP : PROCESS(resetB, clk)
    BEGIN
      if resetB='0' then
        outQ <=(others=>'0');
        FOR i IN 0 TO sizeOfDepth-1 LOOP fifoRegI(i) <=(others=>'0'); END LOOP;
      elsif clk'event and clk='1' then
        if enable='1' then
          outQ <=fifoRegI(sizeOfDepth-1);
          FOR i IN sizeOfDepth-2 DOWNTO 0 LOOP
            fifoRegI(i+1) <=fifoRegI(i);
          END LOOP;
          fifoRegI(0) <=inA;
        end if;
      end if;
    END PROCESS;
  END GENERATE;
  ------------------------------------------------------------------------------

  -- synthesis translate_off
  ------------------------------------------------------------------------------
  -- TDD
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- synthesis translate_on
END rtl;
--==============================================================================
