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
-- File Name : c2dOutBuf.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V250603    hkim  2D Conv Output Buffer
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY c2dOutBuf IS
GENERIC(
  OUTPUT_BUF_ACCUM      : BOOLEAN := TRUE;  -- Output buffer accumulation feature On/Off
  imageBufWidthBitSize  : NATURAL := 8;     -- IMAGE_BUF_WIDTH_BITSIZE
  imageBufHeightBitSize : NATURAL := 8;     -- IMAGE_BUF_HEIGHT_BITSIZE
  numOfData             : NATURAL := 8;     -- number of data, OUTPUT_BUF_WIDTH
  sizeOfBitIn           : NATURAL := 8;     -- input bit size
  sizeOfBitOut          : NATURAL := 8      -- output bit size
);
PORT(
  outValid        : out std_logic;
  bufOut          : out std_logic_vector(numOfData*sizeOfBitOut-1 downto 0);
  bufInit         : in  std_logic;
  bufEn           : in  std_logic;
  bufIn           : in  std_logic_vector(sizeOfBitIn-1 downto 0);
  endOfRow        : in  std_logic;
  numRow          : in  std_logic_vector(7 downto 0);
  strWidthCnt     : in  std_logic_vector(imageBufWidthBitSize-1 downto 0);
  strHeightCnt    : in  std_logic_vector(imageBufHeightBitSize-1 downto 0);
  isFirst         : in  std_logic;
  outAccumEn      : in  std_logic;
  outAccumLast    : in  std_logic;
  endOfConv       : in  std_logic;
  obRegFileCnt    : in  std_logic_vector(imageBufHeightBitSize-1 downto 0);
  obRegFileWrEn   : in  std_logic;
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF c2dOutBuf IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  -- Array
  TYPE outBufType IS ARRAY(0 TO numOfData-1) OF std_logic_vector(sizeOfBitOut-1 downto 0);
  SIGNAL  outBufData : outBufType;

  -- Output Accumulation Register File
  TYPE outBufAccumRegType IS ARRAY (0 TO numOfData-1) OF outBufType;
  SIGNAL  outBufAccumRegFile  : outBufAccumRegType;
  SIGNAL  outBufRegFileCntI   : NATURAL RANGE 0 TO numOfData-1;

  -- Array-to-Vector
  FUNCTION arrayToVector( arrayIn       : outBufType;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN std_logic_vector IS
    VARIABLE vectorOut : std_logic_vector(arraySize*elemWidth-1 downto 0);
  BEGIN
    FOR i IN 0 TO arraySize-1 LOOP
      vectorOut((i+1)*elemWidth-1 downto i*elemWidth) := arrayIn(arrayIn'LEFT+i);
    END LOOP;
    RETURN vectorOut;
  END FUNCTION;
  
  SIGNAL  bufCntInI   : NATURAL RANGE 0 TO numOfData-1;
  SIGNAL  bufCntInIA  : NATURAL RANGE 0 TO numOfData-1;
  CONSTANT  zeroSlv   : outBufType :=(others=>(others=>'0'));
  SIGNAL  strHeightCntD1  : std_logic_vector(imageBufHeightBitSize-1 downto 0);

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
  OUTPUT_BUF_ACCUM_OFF_G0 : IF ( OUTPUT_BUF_ACCUM = FALSE ) GENERATE
  ------------------------------------------------------------------------------
    -- Output Data, OB
    bufDataInP : PROCESS(all)
    BEGIN
      if resetB='0' then outBufData <=zeroSlv;
      elsif rising_edge(clk) then
        if    (bufInit='1') then outBufData <=zeroSlv;
        elsif ((bufEn='1') AND (to_integer(unsigned(strWidthCnt))=0) AND (to_integer(unsigned(strHeightCnt))=0)) then
          outBufData(bufCntInI) <=std_logic_vector(resize(signed(bufIn), sizeOfBitOut));
        end if;
      end if;
    END PROCESS;
    
    -- Input Data Counter
    bufCntInIP : PROCESS(all)
    BEGIN
      if resetB='0' then bufCntInI <=0;
      elsif rising_edge(clk) then
        if    (bufInit='1') then bufCntInI <=0;
        elsif (endOfRow='1') then bufCntInI <=0;
        elsif ((bufEn='1') AND (to_integer(unsigned(strWidthCnt))=0) AND (to_integer(unsigned(strHeightCnt))=0)) then
          if bufCntInI=to_integer(unsigned(numRow))-1 then bufCntInI <=0;
          else bufCntInI <=bufCntInI +1; end if;
        end if;
      end if;
    END PROCESS;
    
    -- Output Data
    bufOutP : PROCESS(all)
      VARIABLE bufOutV : outBufType;
    BEGIN
      if resetB='0' then bufOut <=(others=>'0');
      elsif rising_edge(clk) then
        if    (bufInit='1') then bufOut <=(others=>'0');
        elsif (endOfRow='1') then
          bufOut <=arrayToVector( outBufData, numOfData, sizeOfBitOut );
        end if;
      end if;
    END PROCESS;
    
    outValidP : PROCESS(all)
    BEGIN
      if resetB='0' then outValid <='0';
      elsif rising_edge(clk) then
        if endOfRow='1' AND to_integer(unsigned(strHeightCnt))=0 then outValid <='1';
        else                                                          outValid <='0'; end if;
      end if;
    END PROCESS;
  ------------------------------------------------------------------------------
  END GENERATE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  OUTPUT_BUF_ACCUM_ON_G1 : IF ( OUTPUT_BUF_ACCUM = TRUE ) GENERATE
  ------------------------------------------------------------------------------
    -- Output Data, OB
    bufDataInP : PROCESS(all)
      VARIABLE  bufInV    : signed(sizeOfBitOut-1 downto 0);
      VARIABLE  regFileV  : signed(sizeOfBitOut-1 downto 0);
      VARIABLE  accumV    : signed(sizeOfBitOut-1 downto 0);
    BEGIN
      if resetB='0' then outBufData <=zeroSlv;
      elsif rising_edge(clk) then
        if    (bufInit='1') then outBufData <=zeroSlv;
        elsif ((bufEn='1') AND (to_integer(unsigned(strWidthCnt))=0) AND (to_integer(unsigned(strHeightCnt))=0)) then
          if (outAccumEn='1') then  -- accumulation mode
              outBufData(bufCntInIA) <=std_logic_vector(resize(signed(bufIn), sizeOfBitOut));
          else                    --   after first time
            bufInV    :=resize(signed(bufIn), sizeOfBitOut);
            regFileV  :=signed( outBufAccumRegFile(to_integer(unsigned(obRegFileCnt)))(bufCntInIA) );
            accumV    :=regFileV + bufInV;
            outBufData(bufCntInIA) <=std_logic_vector(accumV);
          end if;
        end if;
      end if;
    END PROCESS;

    -- Input Data Counter
    bufCntInIP : PROCESS(all)
    BEGIN
      if resetB='0' then bufCntInIA <=0;
      elsif rising_edge(clk) then
        if    (bufInit='1') then bufCntInIA <=0;
        elsif (obRegFileWrEn='1') then bufCntInIA <=0;
        elsif ((bufEn='1') AND (to_integer(unsigned(strWidthCnt))=0) AND (to_integer(unsigned(strHeightCnt))=0)) then
          if bufCntInIA=to_integer(unsigned(numRow))-1 then bufCntInIA <=0;
          else bufCntInIA <=bufCntInIA +1; end if;
        end if;
      end if;
    END PROCESS;

    -- Output Buffer Register File Counter
    outBufRegFileCntIP : PROCESS(all)
    BEGIN
      if resetB='0' then outBufRegFileCntI <=0;
      elsif rising_edge(clk) then
        if (isFirst='1' AND bufInit='1') then outBufRegFileCntI <=0;
        elsif (endOfConv='1') then outBufRegFileCntI <=0;
        elsif (obRegFileWrEn='1') then
          if outBufRegFileCntI=to_integer(unsigned(numRow))-1 then outBufRegFileCntI <=0;
          else outBufRegFileCntI <=outBufRegFileCntI +1; end if;
        end if;
      end if;
    END PROCESS;

    -- Output Data
    bufOutP : PROCESS(all)
      VARIABLE bufOutV : outBufType;
    BEGIN
      if resetB='0' then bufOut <=(others=>'0');
      elsif rising_edge(clk) then
        if obRegFileWrEn='1' then
          outBufAccumRegFile(to_integer(unsigned(obRegFileCnt))) <=outBufData;
        end if;
        if outAccumLast='1' then
          if    (bufInit='1') then bufOut <=(others=>'0');
          elsif (obRegFileWrEn='1') then
            bufOut <=arrayToVector( outBufData, numOfData, sizeOfBitOut );
          end if;
        end if;
      end if;
    END PROCESS;

    outValidP : PROCESS(all)
    BEGIN
      if resetB='0' then outValid <='0';
      elsif rising_edge(clk) then
        if outAccumLast='1' then
          if obRegFileWrEn='1' AND to_integer(unsigned(strHeightCntD1))=0 then outValid <='1';
          else                                                                 outValid <='0'; end if;
        end if;
      end if;
    END PROCESS;

    strHeightCntD1P : PROCESS(all)
    BEGIN
      if resetB='0' then strHeightCntD1 <=(others=>'0');
      elsif rising_edge(clk) then
        strHeightCntD1 <=strHeightCnt;
      end if;
    END PROCESS;
  ------------------------------------------------------------------------------
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
