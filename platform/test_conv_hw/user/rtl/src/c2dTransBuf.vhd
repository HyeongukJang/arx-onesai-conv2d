--------------------------------------------------------------------------------
--
-- Copyright(c) 2025 Electronics and Telecommunications Research Institute(ETRI)
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
-- Copyright Human Body Communication 2025, All rights reserved.
-- AI Edge SoC Research Section, AI SoC Research Division,
-- Artificial Intelligence Research Laboratory
-- Electronics and Telecommunications Research Institute (ETRI)
--------------------------------------------------------------------------------

--==============================================================================
-- File Name : c2dTransBuf.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V250523    hkim  2D Conv Transpose Buffer
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY c2dTransBuf IS
GENERIC(
  numOfWidth      : NATURAL := 8;   -- number of BUF_WIDTH  , HW
  numOfHeight     : NATURAL := 8;   -- number of BUF_HEIGHT , HW
  numOfHeightOut  : NATURAL := 8;   -- number of BUF_HEIGHT for Output
  sizeOfBitIn     : NATURAL := 8;   -- bit size
  sizeOfBitCnt    : NATURAL := 8
);
PORT(
  outValid        : out std_logic;
  bufLineOut      : out std_logic_vector(numOfHeightOut*sizeOfBitIn-1 downto 0);
  bufLdInit       : in  std_logic;
  bufLdEn         : in  std_logic;
  bufLdEnd        : in  std_logic;
  bufLineIn       : in  std_logic_vector(numOfWidth*sizeOfBitIn-1 downto 0);
  numRow          : in  std_logic_vector(7 downto 0); -- from mi_info or mk_info
  bufRdInit       : in  std_logic;
  bufRdEn         : in  std_logic;
  outHeightCnt    : in  std_logic_vector(sizeOfBitCnt-1 downto 0);
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF c2dTransBuf IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  -- Array
  TYPE rowType IS ARRAY(0 TO numOfWidth-1) OF std_logic_vector(sizeOfBitIn-1 downto 0);
  TYPE bufType IS ARRAY(0 TO numOfHeight-1) OF rowType;
  SIGNAL  bufData : bufType;

  TYPE outRowType IS ARRAY(0 TO numOfHeightOut-1) OF std_logic_vector(sizeOfBitIn-1 downto 0);

  -- Vector-to-Array
  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN rowType IS
    VARIABLE arrayOut : rowType;
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  -- Array-to-Vector
  FUNCTION arrayToVector( arrayIn       : outRowType;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN std_logic_vector IS
    VARIABLE vectorOut : std_logic_vector(arraySize*elemWidth-1 downto 0);
  BEGIN
    FOR i IN 0 TO arraySize-1 LOOP
      vectorOut((i+1)*elemWidth-1 downto i*elemWidth) := arrayIn(arrayIn'LEFT+i);
    END LOOP;
    RETURN vectorOut;
  END FUNCTION;
  
  SIGNAL  bufCntInI   : NATURAL RANGE 0 TO numOfHeight-1;
  SIGNAL  bufCntOutI  : NATURAL RANGE 0 TO numOfHeight-1;
  CONSTANT  zeroSlv   : rowType :=(others=>(others=>'0'));

  -- for Monitoring
  -- synthesis translate_off
  -- synthesis translate_on
  -- SIGNAL END

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  -- END GENERATE

  ------------------------------------------------------------------------------
  -- SIGNAL CONNECTION
  ------------------------------------------------------------------------------
  -- kerBufLineIn  <=kerBufLineInI;
  -- imgBufLineIn  <=imgBufLineInI;
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  -- END MAPPING

  ------------------------------------------------------------------------------
  -- PROCESSES
  ------------------------------------------------------------------------------
  -- Input Data, IB
  bufDataInP : PROCESS(all)
    VARIABLE  bufLineInArrayV : rowType;
  BEGIN
    if resetB='0' then bufData <=(others=>zeroSlv);
    elsif rising_edge(clk) then
      if    (bufLdInit='1') then bufData <=(others=>zeroSlv);
      elsif (bufLdEn='1') then
        bufLineInArrayV :=vectorToArray(bufLineIn, numOfWidth, sizeOfBitIn);
        bufData(bufCntInI) <=bufLineInArrayV;
      end if;
    end if;
  END PROCESS;
    
  -- Input Data Counter
  bufCntInIP : PROCESS(all)
  BEGIN
    if resetB='0' then bufCntInI <=0;
    elsif rising_edge(clk) then
      if    (bufLdInit='1') then bufCntInI <=0;
      elsif (bufLdEn='1' AND bufLdEnd='1') then bufCntInI <=0;
      elsif (bufLdEn='1') then
        if bufCntInI=to_integer(unsigned(numRow))-1 then bufCntInI <=0;
        else bufCntInI <=bufCntInI +1; end if;
      end if;
    end if;
  END PROCESS;

  -- Output Data
  bufDataOutP : PROCESS(all)
    VARIABLE bufLineOutV : outRowType;
    VARIABLE startPtr, endPtr : INTEGER;
  BEGIN
    if resetB='0' then bufLineOut <=(others=>'0');
    elsif rising_edge(clk) then
      if    (bufRdInit='1') then bufLineOut <=(others=>'0');
      elsif (bufRdEn='1') then
        startPtr := to_integer(unsigned(outHeightCnt));
        endPtr   := to_integer(unsigned(outHeightCnt)) + to_integer(unsigned(numRow));
        FOR i IN 0 TO numOfHeightOut-1 LOOP
          if (i >= startPtr) AND ( i <= endPtr-1 ) then
            bufLineOutV(i) :=bufData(i-startPtr)(bufCntOutI);
          else
            bufLineOutV(i) :=(others=>'0');
          end if;
        END LOOP;
        bufLineOut <=arrayToVector(bufLineOutV, numOfHeightOut, sizeOfBitIn);
      end if;
    end if;
  END PROCESS;

  outValidP : PROCESS(all)
  BEGIN
    if resetB='0' then outValid <='0';
    elsif rising_edge(clk) then
      outValid <=bufRdEn;
    end if;
  END PROCESS;
    
  -- Output Data Counter
  bufCntOutIP : PROCESS(all)
  BEGIN
    if resetB='0' then bufCntOutI <=0;
    elsif rising_edge(clk) then
      if    (bufRdInit='1') then bufCntOutI <=0;
      elsif (bufRdEn='1') then
        if bufCntOutI=to_integer(unsigned(numRow))-1 then bufCntOutI <=0;
        else bufCntOutI <=bufCntOutI +1; end if;
      end if;
    end if;
  END PROCESS;
  ------------------------------------------------------------------------------

  -- synthesis translate_off
  ------------------------------------------------------------------------------
  -- TDD
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- synthesis translate_on
END rtl;
--==============================================================================
