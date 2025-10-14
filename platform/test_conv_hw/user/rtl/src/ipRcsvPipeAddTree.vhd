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
-- File Name : ipRcsvPipeAddTree.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V241121    hkim  Recursive Pipelined Adder Tree
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY ipRcsvPipeAddTree IS
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
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF ipRcsvPipeAddTree IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
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

  COMPONENT ipFifo
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
  END COMPONENT;

  COMPONENT ipDelay
  GENERIC(
    sizeOfDepth     : NATURAL := 8
  );
  PORT(
    outQ            : out std_logic;
    inA             : in  std_logic;
    clk             : in  std_logic;
    resetB          : in  std_logic
  );
  END COMPONENT;
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- TYPES
  ------------------------------------------------------------------------------
  TYPE dataArrayType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitIn-1 downto 0);

  ------------------------------------------------------------------------------
  -- FUNCTIONS
  ------------------------------------------------------------------------------
  FUNCTION arrayToVector( arrayIn       : dataArrayType;
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
  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN dataArrayType IS
    VARIABLE arrayOut : dataArrayType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  ------------------------------------------------------------------------------
  FUNCTION getPowerOfTwo(numOfIn : NATURAL) RETURN NATURAL IS
    VARIABLE powerOfTwo : NATURAL;
  BEGIN
    if (numOfIn=0) then powerOfTwo := 1;
    else                powerOfTwo := POSITIVE(2**(log2(real(numOfIn)))); end if;
    RETURN powerOfTwo;
  END FUNCTION;

  ------------------------------------------------------------------------------
  FUNCTION getTreeDepth(numOfIn : NATURAL) RETURN NATURAL IS
    VARIABLE treeDepth : NATURAL;
  BEGIN
    if (numOfIn=0) then treeDepth :=0;
    else                treeDepth :=NATURAL(ceil(log2(real(numOfIn)))); end if;
    RETURN treeDepth;
  END FUNCTION;

  ------------------------------------------------------------------------------
  FUNCTION getTreeOutBitWidth(numOfIn : NATURAL; elemWidth : NATURAL) RETURN NATURAL IS
    VARIABLE treeOutBitWidth : NATURAL;
    VARIABLE treeDepth       : NATURAL;
  BEGIN
    if (numOfIn=0) then treeDepth :=0;
    else                treeDepth :=NATURAL(ceil(log2(real(numOfIn)))); end if;
    if (numOfIn>0) then treeOutBitWidth := elemWidth + treeDepth;
    else                treeOutBitWidth := elemWidth; end if;
    RETURN treeOutBitWidth;
  END FUNCTION;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  CONSTANT TREE_INPUT_RIGHT   : NATURAL :=numOfInput/2;
  CONSTANT TREE_INPUT_LEFT    : NATURAL :=numOfInput -TREE_INPUT_RIGHT; -- TREE_INPUT_LEFT >= TREE_INPUT_RIGHT
  CONSTANT TREE_DEPTH_LEFT    : NATURAL :=getTreeDepth(TREE_INPUT_LEFT);
  CONSTANT TREE_DEPTH_RIGHT   : NATURAL :=getTreeDepth(TREE_INPUT_RIGHT);
  CONSTANT TREE_DEPTH_DIFF    : NATURAL :=TREE_DEPTH_LEFT -TREE_DEPTH_RIGHT;
  CONSTANT TREE_OUT_BIT_LEFT  : NATURAL :=getTreeOutBitWidth(TREE_INPUT_LEFT, sizeOfBitIn);
  CONSTANT TREE_OUT_BIT_RIGHT : NATURAL :=getTreeOutBitWidth(TREE_INPUT_RIGHT, sizeOfBitIn);
  SIGNAL  outTreeLeftI            : std_logic_vector(TREE_OUT_BIT_LEFT-1 downto 0);
  SIGNAL  outTreeRightI           : std_logic_vector(TREE_OUT_BIT_RIGHT-1 downto 0);
  SIGNAL  outTreeRightUnAlignedI  : std_logic_vector(TREE_OUT_BIT_RIGHT-1 downto 0);
  SIGNAL  inDataArrayI            : dataArrayType(0 TO numOfInput-1);
  SIGNAL  inDataTreeLeftI         : std_logic_vector(TREE_INPUT_LEFT*sizeOfBitIn-1 downto 0);
  SIGNAL  inDataTreeRightI        : std_logic_vector(TREE_INPUT_RIGHT*sizeOfBitIn-1 downto 0);
  SIGNAL  enableDelayedI          : std_logic;
  SIGNAL  enableAllI              : std_logic;
  SIGNAL  enableDelayedID1        : std_logic;
  -- SIGNAL END

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  -- Input data array generation
  inDataArrayI <=vectorToArray( inVec, numOfInput, sizeOfBitIn );
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Base Case 1: numOfInput = 1 : out = in(0)
  ------------------------------------------------------------------------------
  BASE_CASE1_GEN0 : IF ( numOfInput = 1 ) GENERATE
    outQ <=inDataArrayI(0);
    outValid <=enable;
  END GENERATE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Base Case 2: numOfInput = 2 : out = in(0)+in(1)
  ------------------------------------------------------------------------------
  BASE_CASE2_GEN0 : IF ( numOfInput = 2 ) GENERATE
    baseCase2GenP : PROCESS(all)
    BEGIN
      if resetB='0' then outQ <=(others=>'0');
                         outValid <='0';
      elsif (rising_edge(clk)) then
        if (enable='1') then
          outQ <=std_logic_vector(resize(signed(inDataArrayI(0)), sizeOfBitIn+1) +
                                  resize(signed(inDataArrayI(1)), sizeOfBitIn+1));
          outValid <='1';
        else
          outValid <='0';
        end if;
      end if;
    END PROCESS;
  END GENERATE;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Recursive Pipelined Adder Tree Generation: numOfInput > 2
  ------------------------------------------------------------------------------
  RECURSIVE_ADDER_TREE_GEN0 : IF ( numOfInput > 2 ) GENERATE

    enableAllI <=enable OR enableDelayedI;

    ----------------------------------------------------------------------------
    -- Left Tree
    ----------------------------------------------------------------------------
    inDataTreeLeftI <=arrayToVector( inDataArrayI(0 TO TREE_INPUT_LEFT-1), TREE_INPUT_LEFT, sizeOfBitIn );

    u_Tree_Left : ipRcsvPipeAddTree
    GENERIC MAP(
      numOfInput      => TREE_INPUT_LEFT,
      sizeOfBitIn     => sizeOfBitIn
    )
    PORT MAP(
      outValid        => OPEN            ,
      outQ            => outTreeLeftI    ,
      inVec           => inDataTreeLeftI ,
      enable          => enableAllI      ,
      clk             => clk             ,
      resetB          => resetB
    );
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- Right Tree
    ----------------------------------------------------------------------------
    inDataTreeRightI <=arrayToVector( inDataArrayI(TREE_INPUT_LEFT TO numOfInput-1), TREE_INPUT_RIGHT, sizeOfBitIn );

    u_Tree_Right : ipRcsvPipeAddTree
    GENERIC MAP(
      numOfInput      => TREE_INPUT_RIGHT,
      sizeOfBitIn     => sizeOfBitIn
    )
    PORT MAP(
      outValid        => OPEN            ,
      outQ            => outTreeRightUnAlignedI,
      inVec           => inDataTreeRightI,
      enable          => enableAllI      ,
      clk             => clk             ,
      resetB          => resetB
    );
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- Extra Delay for Right Tree
    ----------------------------------------------------------------------------
    EXTRA_DELAY_GEN0 : IF ( TREE_DEPTH_DIFF = 0 ) GENERATE  -- evenly aligned: bypass
      outTreeRightI <=outTreeRightUnAlignedI;
    END GENERATE;
    
    EXTRA_DELAY_GEN1 : IF ( TREE_DEPTH_DIFF > 0 ) GENERATE  -- odd aligned: extra delay
      u_ipFifo : ipFifo
      GENERIC MAP(
        sizeOfWidth     => outTreeRightUnAlignedI'LENGTH,
        sizeOfDepth     => TREE_DEPTH_DIFF
      )
      PORT MAP(
        outQ            => outTreeRightI   ,
        inA             => outTreeRightUnAlignedI,
        enable          => enableAllI      ,
        clk             => clk             ,
        resetB          => resetB
      );
    END GENERATE;

    ----------------------------------------------------------------------------
    -- ADD TREE
    ----------------------------------------------------------------------------
    addTreeP : PROCESS(all)
    BEGIN
      if resetB='0' then outQ <=(others=>'0');
      elsif (rising_edge(clk)) then
        if (enableAllI='1') then
          outQ <=std_logic_vector( resize(signed(outTreeLeftI),  outQ'LENGTH) +
                                   resize(signed(outTreeRightI), outQ'LENGTH) );
        end if;
      end if;
    END PROCESS;

    ----------------------------------------------------------------------------
    -- Extra Delay for enable signal
    ----------------------------------------------------------------------------
    u_ipDelay : ipDelay
    GENERIC MAP(
      sizeOfDepth     => TREE_DEPTH_LEFT
    )
    PORT MAP(
      outQ            => enableDelayedI  ,
      inA             => enable          ,
      clk             => clk             ,
      resetB          => resetB
    );
    OUT_VALID_GEN0 : IF ( numOfInput <= 4 ) GENERATE
      outValid <=enableDelayedID1;
      delayP : PROCESS(all)
      BEGIN
        if resetB='0' then enableDelayedID1 <='0';
        elsif rising_edge(clk) then
          enableDelayedID1 <=enableDelayedI;
        end if;
      END PROCESS;
    END GENERATE;
    OUT_VALID_GEN1 : IF ( numOFInput >  4 ) GENERATE 
      outValid <=enableDelayedI;
    END GENERATE;
    ----------------------------------------------------------------------------
  END GENERATE;
  -- END GENERATE

  ------------------------------------------------------------------------------
  -- SIGNAL CONNECTION
  ------------------------------------------------------------------------------
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  -- EXAMPLE
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
