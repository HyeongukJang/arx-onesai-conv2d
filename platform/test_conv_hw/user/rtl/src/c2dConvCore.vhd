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
-- File Name : c2dConvCore.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V241202    hkim  2D Convolution Core
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY c2dConvCore IS
GENERIC(
  imageBufWidth     : NATURAL :=  14;   -- Image Buffer Width,  IMAGE_BUF_WIDTH
  numOfWidth        : NATURAL :=   8;   -- number of WIDTH    , KERNEL_BUF_WIDTH
  numOfHeight       : NATURAL :=   8;   -- number of HEIGHT   , IMAGE_BUF_HEIGHT
  sizeOfBitImgIn    : NATURAL :=   8;   -- bit size of image  , IMAGE_BUF_BITSIZE
  sizeOfBitKerIn    : NATURAL :=   8    -- bit size of kernel , KERNEL_BUF_BITSIZE
);
PORT(
  convCoreEnd     : out std_logic;
  convCoreValid   : out std_logic;
  convCoreOut     : out std_logic_vector(sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfWidth))))+INTEGER(ceil(log2(real(numOfHeight))))-1 downto 0);
  kerBufFull      : out std_logic;
  imgBufFull      : out std_logic;
  imgBufEmpty     : out std_logic;
  kerBufInit      : in  std_logic;
  kerBufLdEn      : in  std_logic;
  kerBufRdEn      : in  std_logic;
  kerBufLineIn    : in  std_logic_vector(numOfHeight*sizeOfBitKerIn-1 downto 0);
  imgBufInit      : in  std_logic;
  imgBufLdEn      : in  std_logic;
  imgBufRdEn      : in  std_logic;
  imgBufLineIn    : in  std_logic_vector(numOfHeight*sizeOfBitImgIn-1 downto 0);
  addTreeEn       : in  std_logic;
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF c2dConvCore IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  COMPONENT c2dConvCoreLine
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
  END COMPONENT;

  COMPONENT ipRcsvPipeAddTree
  GENERIC(
    numOfInput      : NATURAL := 8;   -- number of input
    sizeOfBitIn     : NATURAL := 8    -- bit size of input
  );
  PORT(
    outValid        : out std_logic;
    outQ            : out std_logic_vector(sizeOfBitIn + INTEGER(ceil(log2(real(numOfInput))))-1 downto 0);
    inVec           : in  std_logic_vector(numOfInput*sizeOfBitIn-1 downto 0);
    enable          : in  std_logic;
    clk             : in  std_logic;
    resetB          : in  std_logic
  );
  END COMPONENT;

  COMPONENT ipMonoPulseSeFF
  	PORT(
  		q		          : out std_logic;
  		qB		        : out std_logic;
  		enable		    : in  std_logic;
  		syncResetB	  : in  std_logic;
  		clk		        : in  std_logic;
  		resetB		    : in  std_logic
  	);
  END COMPONENT;
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- TYPE DECLARATION
  ------------------------------------------------------------------------------
  TYPE  imgBufInArrayType     IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitImgIn-1 downto 0);
  TYPE  kerBufInArrayType     IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitKerIn-1 downto 0);
  TYPE  convLineOutArrayType  IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfWidth))))-1 downto 0);
  TYPE  signalArrayType       IS ARRAY (NATURAL RANGE<>) OF std_logic;

  ------------------------------------------------------------------------------
  -- FUNCTIONS
  ------------------------------------------------------------------------------
  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN imgBufInArrayType IS
    VARIABLE arrayOut : imgBufInArrayType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN kerBufInArrayType IS
    VARIABLE arrayOut : kerBufInArrayType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN convLineOutArrayType IS
    VARIABLE arrayOut : convLineOutArrayType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  FUNCTION arrayToVector( arrayIn       : convLineOutArrayType;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN std_logic_vector IS
    VARIABLE vectorOut : std_logic_vector(arraySize*elemWidth-1 downto 0);
  BEGIN
    FOR i IN 0 TO arraySize-1 LOOP
      vectorOut((i+1)*elemWidth-1 downto i*elemWidth) := arrayIn(arrayIn'LEFT+i);
    END LOOP;
    RETURN vectorOut;
  END FUNCTION;

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  SIGNAL  imgBufInArrayI    : imgBufInArrayType(0 TO numOfHeight-1);  -- Image Buffer Input
  SIGNAL  kerBufInArrayI    : kerBufInArrayType(0 TO numOfHeight-1);  -- Kernel Buffer Input
  SIGNAL  convLineOutArrayI : convLineOutArrayType(0 TO numOfHeight-1);  -- c2dConvCoreLine output
  SIGNAL  convLineValidI    : signalArrayType(0 TO numOfHeight-1);
  SIGNAL  imgBufFullI       : signalArrayType(0 TO numOfHeight-1);
  SIGNAL  imgBufEmptyI      : signalArrayType(0 TO numOfHeight-1);
  SIGNAL  kerBufFullI       : signalArrayType(0 TO numOfHeight-1);
  SIGNAL  addTreeInI        : std_logic_vector(numOfHeight*(sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfWidth)))))-1 downto 0);
  SIGNAL  convCoreOutI      : std_logic_vector(sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfWidth))))+INTEGER(ceil(log2(real(numOfHeight))))-1 downto 0);
  SIGNAL  convCoreValidI    : std_logic;
  SIGNAL  convCoreEndI      : std_logic;
  -- SIGNAL END

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  -- END GENERATE

  ------------------------------------------------------------------------------
  -- SIGNAL CONNECTION
  ------------------------------------------------------------------------------
  convCoreEnd     <=convCoreEndI;
  convCoreValid   <=convCoreValidI;
  convCoreOut     <=convCoreOutI;
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  CONV2D_GEN0 : FOR i IN 0 TO numOfHeight-1 GENERATE
      -- Vector to Array
      imgBufInArrayI  <=vectorToArray( imgBufLineIn, numOfHeight, sizeOfBitImgIn );
      kerBufInArrayI  <=vectorToArray( kerBufLineIn, numOfHeight, sizeOfBitKerIn );

      -- Line Convolution
      i_c2dConvCoreLine : c2dConvCoreLine
      GENERIC MAP(
        imageBufWidth     => imageBufWidth   ,  -- IMAGE_BUF_WIDTH
        numOfInput        => numOfWidth      ,  -- KERNEL_BUF_WIDTH
        sizeOfBitImgIn    => sizeOfBitImgIn  ,  -- IMAGE_BUF_BITSIZE
        sizeOfBitKerIn    => sizeOfBitKerIn     -- KERNEL_BUF_BITSIZE
      )
      PORT MAP(
        convLineValid   => convLineValidI(i)    ,
        convLineOut     => convLineOutArrayI(i) ,
        imgBufFull      => imgBufFullI(i)       ,
        imgBufEmpty     => imgBufEmptyI(i)      ,
        kerBufFull      => kerBufFullI(i)       ,
        imgBufInit      => imgBufInit           ,
        imgBufLdEn      => imgBufLdEn           ,
        imgBufRdEn      => imgBufRdEn           ,
        imgBufLineIn    => imgBufInArrayI(i)    ,
        kerBufInit      => kerBufInit           ,
        kerBufLdEn      => kerBufLdEn           ,
        kerBufRdEn      => kerBufRdEn           ,
        kerBufLineIn    => kerBufInArrayI(i)    ,
        clk             => clk                  ,
        resetB          => resetB
      );
    END GENERATE;

    -- Array to Vector
    addTreeInI  <=arrayToVector( convLineOutArrayI, numOfHeight, (sizeOfBitImgIn+sizeOfBitKerIn+INTEGER(ceil(log2(real(numOfWidth))))) );

    -- Final Adder Tree
    i_ipRcsvPipeAddTree : ipRcsvPipeAddTree
    GENERIC MAP(
      numOfInput      => numOfHeight,
      sizeOfBitIn     => sizeOfBitImgIn + sizeOfBitKerIn + INTEGER(ceil(log2(real(numOfWidth))))
    )
    PORT MAP(
      outValid        => convCoreValidI  ,
      outQ            => convCoreOutI    ,
      inVec           => addTreeInI      ,
      enable          => convLineValidI(0),
      clk             => clk             ,
      resetB          => resetB
    );

    i_ipMonoPulseSeFF : ipMonoPulseSeFF
    PORT MAP(
      q               => OPEN            ,
      qB              => convCoreEndI    ,
      enable          => convCoreValidI  ,
      syncResetB      => '1'             ,
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
  ------------------------------------------------------------------------------
  -- synthesis translate_on
END rtl;
--==============================================================================
