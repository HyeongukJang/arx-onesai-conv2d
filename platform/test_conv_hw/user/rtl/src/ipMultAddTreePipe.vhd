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
-- File Name : ipMultAddTreePipe.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V241203    hkim  Pipelined Muliplier-Adder Tree
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY ipMultAddTreePipe IS
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
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF ipMultAddTreePipe IS
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
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- TYPES
  ------------------------------------------------------------------------------
  TYPE dataArrayAType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitInA-1 downto 0);
  TYPE dataArrayBType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitInB-1 downto 0);
  TYPE multArrayType IS ARRAY (NATURAL RANGE<>) OF std_logic_vector(sizeOfBitInA+sizeOfBitInB-1 downto 0);

  ------------------------------------------------------------------------------
  -- FUNCTIONS
  ------------------------------------------------------------------------------
  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN dataArrayAType IS
    VARIABLE arrayOut : dataArrayAType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  FUNCTION vectorToArray( vectorIn      : std_logic_vector;
                          arraySize     : NATURAL;
                          elemWidth     : POSITIVE) RETURN dataArrayBType IS
    VARIABLE arrayOut : dataArrayBType(0 to arraySize-1);
  BEGIN
    FOR i IN 0 to arraySize-1 LOOP
      arrayOut(i) := vectorIn( (i+1)*elemWidth-1 downto i*elemWidth );
    END LOOP;
    RETURN arrayOut;
  END FUNCTION;

  FUNCTION arrayToVector( arrayIn       : multArrayType;
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
  SIGNAL  inDataArrayAI   : dataArrayAType(0 TO numOfInput-1);
  SIGNAL  inDataArrayBI   : dataArrayBType(0 TO numOfInput-1);
  SIGNAL  multOutArrayI   : multArrayType(0 TO numOfInput-1);
  SIGNAL  inDataAddTreeI  : std_logic_vector(numOfInput*(sizeOfBitInA+sizeOfBitInB)-1 downto 0);
  SIGNAL  enableD1I       : std_logic;
  SIGNAL  enableAddTreeI  : std_logic;
  -- SIGNAL END

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- Base Case 1: numOfInput = 1 : out = in(0)
  ------------------------------------------------------------------------------
  MULT_BASE_CASE1_GEN0 : IF ( numOfInput = 1 ) GENERATE
    multBaseCase1GenP : PROCESS(all)
    BEGIN
      if resetB='0' then outQ <=(others=>'0');
      elsif (rising_edge(clk)) then
        if (enable='1') then
          outQ <=std_logic_vector(signed(inVecA)*signed(inVecB));
          outValid <=enable;
        end if;
      end if;
    END PROCESS;
  END GENERATE;

  MULT_ADD_TREE_GEN0 : IF ( numOfInput >= 2 ) GENERATE
    -- Vecto-to-Array
    inDataArrayAI <=vectorToArray( inVecA, numOfInput, sizeOfBitInA );
    inDataArrayBI <=vectorToArray( inVecB, numOfInput, sizeOfBitInB );

    -- Pipelined Multiplication
    PIPE_MULT_GEN0 : FOR i IN 0 TO numOfInput-1 GENERATE
      multP : PROCESS(all)
      BEGIN
        if resetB='0' then multOutArrayI(i) <=(others=>'0');
        elsif (rising_edge(clk)) then
          if (enable='1') then
            multOutArrayI(i) <=std_logic_vector(signed(inDataArrayAI(i))*signed(inDataArrayBI(i)));
          end if;
        end if;
      END PROCESS;
    END GENERATE;
    enableD1IP : PROCESS(all)
    BEGIN
      if resetB='0' then enableD1I <='0';
      elsif (rising_edge(clk)) then
        enableD1I <=enable;
      end if;
    END PROCESS;

    -- Array-to-Vector for Adder Tree
    enableAddTreeI <=enableD1I;
    inDataAddTreeI <=arrayToVector( multOutArrayI, numOfInput, sizeOfBitInA+sizeOfBitInB );

    u_ipRcsvPipeAddTree : ipRcsvPipeAddTree
    GENERIC MAP(
      numOfInput      => numOfInput,
      sizeOfBitIn     => sizeOfBitInA + sizeOfBitInB
    )
    PORT MAP(
      outValid        => outValid        ,
      outQ            => outQ            ,
      inVec           => inDataAddTreeI  ,
      enable          => enableAddTreeI  ,
      clk             => clk             ,
      resetB          => resetB
    );

  END GENERATE;
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
  ------------------------------------------------------------------------------

  -- synthesis translate_off
  ------------------------------------------------------------------------------
  -- TDD
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- synthesis translate_on
END rtl;
--==============================================================================
