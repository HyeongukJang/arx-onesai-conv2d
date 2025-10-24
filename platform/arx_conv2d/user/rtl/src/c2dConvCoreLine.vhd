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
-- File Name : c2dConvCoreLine.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V241202    hkim  1D Convolution Core
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY c2dConvCoreLine IS
GENERIC(
  imageBufWidth     : NATURAL :=  14;   -- Image Buffer Width,  IMAGE_BUF_WIDTH
  numOfInput        : NATURAL :=   8;   -- number of input    , KERNEL_BUF_WIDTH
  sizeOfBitImgIn    : NATURAL :=   8;   -- bit size of image  , IMAGE_BUF_BITSIZE
  sizeOfBitKerIn    : NATURAL :=   8    -- bit size of kernel , KERNEL_BUF_BITSIZE
);
PORT(
  convLineValid   : out std_logic;
  convLineOut     : out std_logic_vector(sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfInput))))-1 downto 0);
  kerBufFull      : out std_logic;
  imgBufFull      : out std_logic;
  imgBufEmpty     : out std_logic;
  kerBufInit      : in  std_logic;
  kerBufLdEn      : in  std_logic;
  kerBufRdEn      : in  std_logic;
  kerBufLineIn    : in  std_logic_vector(sizeOfBitKerIn-1 downto 0);
  imgBufInit      : in  std_logic;
  imgBufLdEn      : in  std_logic;
  imgBufRdEn      : in  std_logic;
  imgBufLineIn    : in  std_logic_vector(sizeOfBitImgIn-1 downto 0);
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF c2dConvCoreLine IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  COMPONENT c2dImgBufLine
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
  END COMPONENT;

  COMPONENT c2dKerBufLine
  GENERIC(
    numOfInput      : NATURAL := 8;   -- number of input    , KERNEL_BUF_WIDTH
    sizeOfBitIn     : NATURAL := 8    -- bit size of input  , KERNEL_BUF_BITSIZE
  );
  PORT(
    kerBufFull      : out std_logic;
    kerBufLineOut   : out std_logic_vector(numOfInput*sizeOfBitIn-1 downto 0);
    kerBufInit      : in  std_logic;
    kerBufLdEn      : in  std_logic;
    kerBufRdEn      : in  std_logic;
    kerBufLineIn    : in  std_logic_vector(           sizeOfBitIn-1 downto 0);
    clk             : in  std_logic;
    resetB          : in  std_logic
  );
  END COMPONENT;

  COMPONENT ipMultAddTreePipe
  GENERIC(
    numOfInput      : NATURAL := 8;   -- number of input
    sizeOfBitInA    : NATURAL := 8;   -- bit size of input A
    sizeOfBitInB    : NATURAL := 8    -- bit size of input B
  );
  PORT(
    outValid        : out std_logic;
    outQ            : out std_logic_vector(sizeOfBitInA +sizeOfBitInB +INTEGER(ceil(log2(real(numOfInput))))-1 downto 0);
    inVecA          : in  std_logic_vector(numOfInput*sizeOfBitInA-1 downto 0);
    inVecB          : in  std_logic_vector(numOfInput*sizeOfBitInB-1 downto 0);
    enable          : in  std_logic;
    clk             : in  std_logic;
    resetB          : in  std_logic
  );
  END COMPONENT;
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  SIGNAL  imgBufFullI     : std_logic;
  SIGNAL  imgBufEmptyI    : std_logic;
  SIGNAL  imgBufOutValidI : std_logic;
  SIGNAL  imgBufLineOutI  : std_logic_vector(numOfInput*sizeOfBitImgIn-1 downto 0);
  SIGNAL  kerBufFullI     : std_logic;
  SIGNAL  kerBufLineOutI  : std_logic_vector(numOfInput*sizeOfBitKerIn-1 downto 0);
  SIGNAL  outValidI       : std_logic;
  SIGNAL  outQI           : std_logic_vector(sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfInput))))-1 downto 0);

  -- synthesis translate_off
  TYPE kerBufType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitKerIn-1 downto 0);
  TYPE imgBufType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitImgIn-1 downto 0);

  SIGNAL  kerBufLineOutVecI : kerBufType(0 TO numOfInput-1);
  SIGNAL  imgBufLineOutVecI : imgBufType(0 TO numOfInput-1);

  FUNCTION vectorToArrayK( vectorIn      : std_logic_vector;
                           arraySize     : NATURAL;
                           elemWidth     : POSITIVE) RETURN kerBufType IS
    VARIABLE arrayOut : kerBufType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  FUNCTION vectorToArrayI( vectorIn      : std_logic_vector;
                           arraySize     : NATURAL;
                           elemWidth     : POSITIVE) RETURN imgBufType IS
    VARIABLE arrayOut : imgBufType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;
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
  convLineValid   <=outValidI;
  convLineOut     <=outQI;
  imgBufFull      <=imgBufFullI;
  imgBufEmpty     <=imgBufEmptyI;
  kerBufFull      <=kerBufFullI;
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  i0_c2dImgBufLine : c2dImgBufLine
  GENERIC MAP(
    imageBufWidth     => imageBufWidth     ,
    numOfInput        => numOfInput        ,
    sizeOfBitIn       => sizeOfBitImgIn
  )
  PORT MAP(
    imgBufFull      => imgBufFullI     ,
    imgBufEmpty     => imgBufEmptyI    ,
    imgBufOutValid  => imgBufOutValidI ,
    imgBufLineOut   => imgBufLineOutI  ,
    imgBufInit      => imgBufInit      ,
    imgBufLdEn      => imgBufLdEn      ,
    imgBufRdEn      => imgBufRdEn      ,
    imgBufLineIn    => imgBufLineIn    ,
    clk             => clk             ,
    resetB          => resetB
  );

  i1_c2dKerBufLine : c2dKerBufLine
  GENERIC MAP(
    numOfInput      => numOfInput     ,
    sizeOfBitIn     => sizeOfBitKerIn
  )
  PORT MAP(
    kerBufFull      => kerBufFullI     ,
    kerBufLineOut   => kerBufLineOutI  ,
    kerBufInit      => kerBufInit      ,
    kerBufLdEn      => kerBufLdEn      ,
    kerBufRdEn      => kerBufRdEn      ,
    kerBufLineIn    => kerBufLineIn    ,
    clk             => clk             ,
    resetB          => resetB
  );

  i2_ipMultAddTreePipe : ipMultAddTreePipe
  GENERIC MAP(
    numOfInput      => numOfInput      ,
    sizeOfBitInA    => sizeOfBitImgIn  ,
    sizeOfBitInB    => sizeOfBitKerIn
  )
  PORT MAP(
    outValid        => outValidI       ,
    outQ            => outQI           ,
    inVecA          => imgBufLineOutI  ,
    inVecB          => kerBufLineOutI  ,
    enable          => imgBufOutValidI ,
    clk             => clk             ,
    resetB          => resetB
  );
  -- END MAPPING

  ------------------------------------------------------------------------------
  -- PROCESSES
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------

  -- synthesis translate_off
  ------------------------------------------------------------------------------
  -- TDD
  ------------------------------------------------------------------------------
  monitorP : PROCESS(all)
  BEGIN
    kerBufLineOutVecI <=vectorToArrayK( kerBufLineOutI, numOfInput, sizeOfBitKerIn);
    imgBufLineOutVecI <=vectorToArrayI( imgBufLineOutI, numOfInput, sizeOfBitImgIn);
  END PROCESS;
  ------------------------------------------------------------------------------
  -- synthesis translate_on
END rtl;
--==============================================================================
