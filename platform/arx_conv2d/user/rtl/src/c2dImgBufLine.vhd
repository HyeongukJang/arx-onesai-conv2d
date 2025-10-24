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
-- File Name : c2dImgBufLine.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V241202    hkim  Image Line Buffer
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY c2dImgBufLine IS
GENERIC(
  imageBufWidth     : NATURAL :=  14;   -- Image Buffer Width,  IMAGE_BUF_WIDTH
  numOfInput        : NATURAL :=   8;   -- number of input    , KERNEL_BUF_WIDTH
  sizeOfBitIn       : NATURAL :=   8    -- bit size of input  , IMAGE_BUF_BITSIZE
);
PORT(
  imgBufFull      : out std_logic;
  imgBufEmpty     : out std_logic;
  imgBufOutValid  : out std_logic;
  imgBufLineOut   : out std_logic_vector(numOfInput*sizeOfBitIn-1 downto 0);
  imgBufInit      : in  std_logic;
  imgBufLdEn      : in  std_logic;
  imgBufRdEn      : in  std_logic;
  imgBufLineIn    : in  std_logic_vector(           sizeOfBitIn-1 downto 0);
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF c2dImgBufLine IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  TYPE imgBufArrayType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitIn-1 downto 0);
  SIGNAL imageBufI    : imgBufArrayType(0 TO numOfInput-1);
  SIGNAL elemCntI     : NATURAL RANGE 0 TO imageBufWidth-1;
  SIGNAL imgBufFullI  : std_logic;
  SIGNAL imgBufEmptyI : std_logic;
  SIGNAL outValidI    : std_logic;
  CONSTANT  zeroSlv   : std_logic_vector(sizeOfBitIn-1 downto 0) :=(others=>'0');

  FUNCTION arrayToVector( arrayIn       : imgBufArrayType;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN std_logic_vector IS
    VARIABLE vectorOut : std_logic_vector(arraySize*elemWidth-1 downto 0);
  BEGIN
    FOR i IN 0 TO arraySize-1 LOOP
      vectorOut((i+1)*elemWidth-1 downto i*elemWidth) := arrayIn(arrayIn'LEFT+i);
    END LOOP;
    RETURN vectorOut;
  END FUNCTION;

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  -- END GENERATE

  ------------------------------------------------------------------------------
  -- SIGNAL CONNECTION
  ------------------------------------------------------------------------------
  imgBufFull  <=imgBufFullI;
  imgBufEmpty <=imgBufEmptyI;
  imgBufOutValid  <=outValidI;
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  -- END MAPPING

  ------------------------------------------------------------------------------
  -- PROCESSES
  ------------------------------------------------------------------------------
  imgBufP : PROCESS(all)
  BEGIN
    if resetB='0' then
      FOR i IN 0 TO numOfInput-1 LOOP imageBufI <=(others=>zeroSlv); END LOOP;
    elsif rising_edge(clk) then
      if (imgBufInit='1') then
        FOR i IN 0 TO numOfInput-1 LOOP imageBufI <=(others=>zeroSlv); END LOOP;
      elsif (imgBufLdEn='1') then
        imageBufI(numOfInput-1) <=imgBufLineIn;
        FOR i IN 0 TO (numOfInput-2) LOOP imageBufI(i) <=imageBufI(i+1); END LOOP;
      end if;
    end if;
  END PROCESS;

  elemCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then elemCntI <=0;
    elsif (rising_edge(clk)) then
      if (imgBufInit='1') then elemCntI <=0;
      elsif (imgBufLdEn='1') then
        if elemCntI=imageBufWidth-1 then elemCntI <=0;
        else elemCntI <=elemCntI +1; end if;
      end if;
    end if;
  END PROCESS;

  imgBufLineOutP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufLineOut <=(others=>'0');
    elsif rising_edge(clk) then
      if (imgBufRdEn='1') then
          imgBufLineOut <=arrayToVector( imageBufI, numOfInput, sizeOfBitIn );
      end if;
    end if;
  END PROCESS;

  outValidIP : PROCESS(all)
  BEGIN
    if resetB='0' then outValidI <='0';
    elsif rising_edge(clk) then
      outValidI <=imgBufRdEn;
    end if;
  END PROCESS;

  imgBufFullEmptyP : PROCESS(all)
  BEGIN
    if elemCntI > numOfInput-1 then imgBufFullI <='1'; imgBufEmptyI <='0';
    else                            imgBufFullI <='0'; imgBufEmptyI <='1'; end if;
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
