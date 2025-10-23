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
-- File Name : c2dConvCoreCtrl.vhd
--==============================================================================
-- Rev.       Des.  Function
-- V250109    hkim  2D Conv Controller
--==============================================================================

--==============================================================================
LIBRARY ieee;   USE ieee.std_logic_1164.all;
                USE ieee.numeric_std.all;
                USE ieee.math_real.all;
--==============================================================================

--==============================================================================
ENTITY c2dConvCoreCtrl IS
GENERIC(
  imageBufWidthBitSize    : NATURAL :=     8; -- IMAGE_BUF_WIDTH_BITSIZE
  imageBufHeightBitSize   : NATURAL :=     8; -- IMAGE_BUF_HEIGHT_BITSIZE
  kernelBufWidthBitSize   : NATURAL :=     8; -- KERNEL_BUF_WIDTH_BITSIZE
  kernelBufHeightBitSize  : NATURAL :=     8; -- KERNEL_BUF_HEIGHT_BITSIZE
  kernelBufWidth          : NATURAL :=     3; -- KERNEL_BUF_WIDTH, Kernel Buffer Width, HW
  imageBufWidth           : NATURAL :=    14; -- IMAGE_BUF_WIDTH , Image Buffer Width,  HW
  imageBufHeight          : NATURAL :=    14; -- IMAGE_BUF_HEIGHT, Image Buffer Height, HW
  OUTPUT_BUF_ACCUM        : BOOLEAN :=  TRUE;  -- Output buffer accumulation feature On/Off
  maxOutputNum            : NATURAL :=    16  -- MAX_OUTPUT_NUM  , for Platform
);
PORT(
  endOfConv2D     : out std_logic;
  extraOutEn      : out std_logic;
  kerBufInit      : out std_logic;
  kerBufLdEn      : out std_logic;
  kerBufRdEn      : out std_logic;
  imgBufInit      : out std_logic;
  imgBufLdEn      : out std_logic;
  imgBufRdEn      : out std_logic;
  addTreeEn       : out std_logic;
  outHeightCnt    : out std_logic_vector(imageBufHeightBitSize-1 downto 0);
  outStrideEn     : out std_logic;
  strWidthCnt     : out std_logic_vector(imageBufWidthBitSize-1 downto 0);
  strHeightCnt    : out std_logic_vector(imageBufHeightBitSize-1 downto 0);
  isFirst         : out std_logic;
  obRegFileCnt    : out std_logic_vector(imageBufHeightBitSize-1 downto 0);
  obRegFileWrEn   : out std_logic;
  npuStart        : in  std_logic;
  convCoreEnd     : in  std_logic;
  convCoreValid   : in  std_logic;
  imgBufFull      : in  std_logic;
  imgBufEmpty     : in  std_logic;
  kerBufFull      : in  std_logic;
  kernelWidth     : in  std_logic_vector(kernelBufWidthBitSize-1 downto 0);
  kernelHeight    : in  std_logic_vector(kernelBufHeightBitSize-1 downto 0);
  imageWidth      : in  std_logic_vector(imageBufWidthBitSize-1 downto 0);
  imageHeight     : in  std_logic_vector(imageBufHeightBitSize-1 downto 0);
  numOutHeight    : in  std_logic_vector(7 downto 0);
  numOfPad        : in  std_logic_vector(7 downto 0);
  numOfStride     : in  std_logic_vector(7 downto 0);
  outBufOutValid  : in  std_logic;
  outAccumEn      : in  std_logic;
  outAccumLast    : in  std_logic;
  clk             : in  std_logic;
  resetB          : in  std_logic
);
END;
--==============================================================================

--==============================================================================
ARCHITECTURE rtl OF c2dConvCoreCtrl IS
  ------------------------------------------------------------------------------
  -- COMPONENT DECLARATION
  ------------------------------------------------------------------------------
  -- COMPONENT END

  ------------------------------------------------------------------------------
  -- SIGNAL DECLARATION
  ------------------------------------------------------------------------------
  -- FSM Example
  TYPE CTRL_STT_MAIN IS (
    idleStt,                        -- IDLE State
    waitStartStt,                   -- Wait 2D Conv NPU Start State
    calcOutNumStt,                  -- Output Number Calculation State

    imgBufInitStt,                  -- Image Buffer Initialization State
    imgBufLdStt,                    -- Image BUffer Load State

    waitDoneStt,                    -- Wait Done State
    calcParaStt,                    -- Parameter calculation state
    chkEndStt,                      -- Check End State
    extraChkStt,                    -- Extra Check State
    extraOutStt,                    -- Extra Output State

    restStt,                        -- Rest State
    postStt                         -- Post State
  );
  SIGNAL  ctrlMainSttI    : CTRL_STT_MAIN;

  SIGNAL  kerBufInitI     : std_logic;
  SIGNAL  kerBufLdStartI  : std_logic;
  SIGNAL  kerBufLdEnI     : std_logic;
  SIGNAL  kerBufLdCntI    : NATURAL RANGE 0 TO kernelBufWidth-1;
  SIGNAL  kerBufLdEndI    : std_logic;
  SIGNAL  kerBufRdEnI     : std_logic;
  SIGNAL  imgBufInitI     : std_logic;
  SIGNAL  imgBufLdStartI  : std_logic;
  SIGNAL  imgBufLdEnI     : std_logic;
  SIGNAL  imgBufLdCntI    : NATURAL RANGE 0 TO imageBufWidth;
  SIGNAL  imgBufLdEndI    : std_logic;
  SIGNAL  imgBufRdStartI  : std_logic;
  SIGNAL  imgBufRdEnI     : std_logic;
  SIGNAL  imgBufRdCntI    : NATURAL RANGE 0 TO imageBufWidth;
  SIGNAL  imgBufRdEndI    : std_logic;
  SIGNAL  addTreeEnI      : std_logic;
  SIGNAL  outNumWidthI    : NATURAL RANGE 0 TO imageBufWidth;
  SIGNAL  outNumHeightI   : NATURAL RANGE 0 TO imageBufHeight;
  SIGNAL  outHeightCntI   : NATURAL RANGE 0 TO imageBufHeight;
  SIGNAL  endOfConv2DI    : std_logic;
  SIGNAL  extraOutEnI     : std_logic;
  SIGNAL  outHeightCntExtraI : NATURAL RANGE 0 TO maxOutputNum;
  SIGNAL  strWidthCntI    : NATURAL RANGE 0 TO imageBufWidth;
  SIGNAL  strHeightCntI   : NATURAL RANGE 0 TO imageBufHeight;
  SIGNAL  strWidthEnI     : std_logic; 
  SIGNAL  strHeightEnI    : std_logic; 
  SIGNAL  outNumStrWidthI : NATURAL RANGE 0 TO imageBufWidth;
  SIGNAL  outNumStrHeighI : NATURAL RANGE 0 TO imageBufHeight;
  SIGNAL  actualOutCntI   : NATURAL RANGE 0 TO imageBufHeight;
  SIGNAL  isFirstI        : std_logic; 
  SIGNAL  isFirstCntI     : NATURAL RANGE 0 TO 3;
  SIGNAL  obRegFileCntI   : NATURAL RANGE 0 TO imageBufHeight;
  SIGNAL  obRegFileWrEnI  : std_logic;
  -- SIGNAL END

BEGIN
  ------------------------------------------------------------------------------
  -- SIGNAL GENERATION
  ------------------------------------------------------------------------------
  -- END GENERATE

  ------------------------------------------------------------------------------
  -- SIGNAL CONNECTION
  ------------------------------------------------------------------------------
  endOfConv2D     <=endOfConv2DI;
  extraOutEn      <=extraOutEnI;
  -- Kernel Buffer
  kerBufInit      <=kerBufInitI;
  kerBufLdEn      <=kerBufLdEnI;
  kerBufRdEn      <=kerBufRdEnI;
  -- Image Buffer
  imgBufInit      <=imgBufInitI;
  imgBufLdEn      <=imgBufLdEnI;
  imgBufRdEn      <=imgBufRdEnI;
  addTreeEn       <=addTreeEnI;
  outHeightCnt    <=std_logic_vector(to_unsigned(outHeightCntI, imageBufHeightBitSize));
  outStrideEn     <=strWidthEnI AND strHeightEnI;
  strWidthCnt     <=std_logic_vector(to_unsigned(strWidthCntI, kernelBufWidthBitSize));
  strHeightCnt    <=std_logic_vector(to_unsigned(strHeightCntI, kernelBufHeightBitSize));
  isFirst         <=isFirstI;
  obRegFileCnt    <=std_logic_vector(to_unsigned(obRegFileCntI, imageBufHeightBitSize));
  obRegFileWrEn   <=obRegFileWrEnI;
  -- END CONNECTION

  ------------------------------------------------------------------------------
  -- PORT MAPPING
  ------------------------------------------------------------------------------
  -- END MAPPING

  ------------------------------------------------------------------------------
  -- PROCESSES
  ------------------------------------------------------------------------------
  mainFsmP : PROCESS(all)
  BEGIN
    if resetB='0' then  ctrlMainSttI <=idleStt;
    elsif rising_edge(clk) then
      case ctrlMainSttI is
        when  idleStt           => ctrlMainSttI <=waitStartStt;       -- IDLE State
        when  waitStartStt      =>
                if npuStart='1' then ctrlMainSttI <=calcOutNumStt;    -- Wait 2D Conv NPU Start State,
                else                 ctrlMainSttI <=waitStartStt;
                end if;
        when  calcOutNumStt     => ctrlMainSttI <=imgBufInitStt;      -- Output Number Calculation State,
        when  imgBufInitStt     => ctrlMainSttI <=imgBufLdStt;        -- Image Buffer Initialization State

        when  imgBufLdStt       =>                                    -- Image BUffer Initial Load State
                if imgBufLdCntI=(to_integer(unsigned(imageWidth)))-1 then ctrlMainSttI <=waitDoneStt;
                else                                                    ctrlMainSttI <=imgBufLdStt;
                end if;
       when  waitDoneStt       =>
                if convCoreEnd='1' then ctrlMainSttI <=calcParaStt;
                else                    ctrlMainSttI <=waitDoneStt;
                end if;
        when  calcParaStt       => ctrlMainSttI <=chkEndStt;          -- Parameter calculation state
        when  chkEndStt         =>
              if to_integer(unsigned(numOfStride))=1 then
                if outHeightCntI=outNumHeightI then
                  if (OUTPUT_BUF_ACCUM=FALSE) then
                    if outHeightCntI=outNumHeightI then ctrlMainSttI <=extraChkStt;
                    else                                ctrlMainSttI <=imgBufInitStt;
                    end if;
                  else
                    if outAccumLast='0' then ctrlMainSttI <=waitStartStt;
                    else                     ctrlMainSttI <=extraChkStt;
                    end if;
                  end if;
                else                                ctrlMainSttI <=imgBufInitStt;
                end if;
              else
                if actualOutCntI=to_integer(unsigned(numOutHeight)) then
                  if (OUTPUT_BUF_ACCUM=FALSE) then
                    if actualOutCntI=to_integer(unsigned(numOutHeight)) then ctrlMainSttI <=extraChkStt;
                    else                                ctrlMainSttI <=imgBufInitStt;
                    end if;
                  else
                    if outAccumLast='0' then ctrlMainSttI <=waitStartStt;
                    else                     ctrlMainSttI <=extraChkStt;
                    end if;
                  end if;
                else                                ctrlMainSttI <=imgBufInitStt;
                end if;
              end if;
        when  extraChkStt       =>
                if outHeightCntExtraI=maxOutputNum then ctrlMainSttI <=restStt;
                else                                 ctrlMainSttI <=extraOutStt; end if;
        when  extraOutStt       => ctrlMainSttI <=extraChkStt;        -- Extra Out State
        when  restStt           => ctrlMainSttI <=postStt;            -- Rest State
        when  postStt           => ctrlMainSttI <=idleStt;            -- Post State

      end case;
    end if;
  END PROCESS;

  outNumWidthIP : PROCESS(all)
  BEGIN
    if resetB='0' then outNumWidthI <=0;
                       outNumHeightI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=calcOutNumStt then
        outNumWidthI <=to_integer(unsigned(imageWidth)) - to_integer(unsigned(kernelWidth)) + 1;
        outNumHeightI <=to_integer(unsigned(imageHeight)) - to_integer(unsigned(kernelHeight)) + 1;
      end if;
    end if;
  END PROCESS;

  -- Kernel Buffer Load End
  kerBufLdEndIP : PROCESS(all)
  BEGIN
    if resetB='0' then kerBufLdEndI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufLdStt AND imgBufLdCntI=to_integer(unsigned(kernelWidth))-1 then kerBufLdEndI <='1';
      else kerBufLdEndI <='0'; end if;
    end if;
  END PROCESS;

  -- Kernel Buffer Read Enable
  kerBufRdEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then kerBufRdEnI <='0';
    elsif rising_edge(clk) then
      kerBufRdEnI <=kerBufLdEndI;
    end if;
  END PROCESS;

  -- Image Buffer Initialization
  imgBufInitIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufInitI <='0';
                       kerBufInitI <='0';
    elsif (rising_edge(clk)) then
      if ctrlMainSttI=imgBufInitStt then imgBufInitI <='1';
                                         kerBufInitI <='1';
      else                               imgBufInitI <='0';
                                         kerBufInitI <='0';
      end if;
    end if;
  END PROCESS;

  -- Image Buffer Load Start
  imgBufLdStartIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufLdStartI <='0';
                       kerBufLdStartI <='0';
    elsif rising_edge(clk) then
      imgBufLdStartI <=imgBufInitI;
      kerBufLdStartI <=kerBufInitI;
    end if;
  END PROCESS;

  -- Image Buffer Load Enable
  imgBufLdEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufLdEnI <='0';
                       kerBufLdEnI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufLdStt then imgBufLdEnI <='1';
        if imgBufLdCntI <= to_integer(unsigned(kernelWidth))-1 then kerBufLdEnI <='1';
        else                                                        kerBufLdEnI <='0'; end if;
      else imgBufLdEnI <='0'; kerBufLdEnI <='0'; end if;
    end if;
  END PROCESS;

  -- Image Buffer Load Counter
  imgBufLdCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufLdCntI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufLdStt then
        if imgBufLdCntI=(to_integer(unsigned(imageWidth))) then imgBufLdCntI <=0;
        else imgBufLdCntI <=imgBufLdCntI +1; end if;
      else imgBufLdCntI <=0; end if;
    end if;
  END PROCESS;

  imgBufLdEndIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufLdEndI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufLdStt AND imgBufLdCntI=(to_integer(unsigned(imageWidth)))-1 then imgBufLdEndI <='1';
      else imgBufLdEndI <='0'; end if;
    end if;
  END PROCESS;

  imgBufRdStartIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufRdStartI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufLdStt AND imgBufLdCntI=to_integer(unsigned(kernelWidth)) then imgBufRdStartI <='1';
      else imgBufRdStartI <='0'; end if;
    end if;
  END PROCESS;

  -- Image Buffer Read Enable Counter
  imgBufRdCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufRdCntI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufInitStt then imgBufRdCntI <=0;
      elsif ctrlMainSttI=imgBufLdStt OR ctrlMainSttI=waitDoneStt then
        if imgBufLdCntI > to_integer(unsigned(kernelWidth))-1 then
          if imgBufRdCntI=outNumWidthI then imgBufRdCntI <=outNumWidthI;
          else imgBufRdCntI <=imgBufRdCntI+1; end if;
        else imgBufRdCntI <=0; end if;
      else imgBufRdCntI <=0; end if;
    end if;
  END PROCESS;

  -- Image Buffer Read Enable
  imgBufRdEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufRdEnI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=imgBufLdStt OR ctrlMainSttI=waitDoneStt then
        if imgBufLdCntI > to_integer(unsigned(kernelWidth))-1 then imgBufRdEnI <='1';
        elsif imgBufRdCntI=outNumWidthI then imgBufRdEnI <='0'; end if;
      else imgBufRdEnI <='0'; end if;
    end if;
  END PROCESS;

  -- Image Buffer Read End
  imgBufRdEndIP : PROCESS(all)
  BEGIN
    if resetB='0' then imgBufRdEndI <='0';
    elsif rising_edge(clk) then
      if imgBufRdCntI = outNumWidthI-1 then imgBufRdEndI <='1';
      else imgBufRdEndI <='0'; end if;
    end if;
  END PROCESS;

  -- Adder Tree Enable
  addTreeEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then addTreeEnI <='0';
    elsif rising_edge(clk) then
      addTreeEnI <=imgBufRdEnI;
    end if;
  END PROCESS;

  outHeightCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then outHeightCntI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=idleStt OR ctrlMainSttI=waitStartStt then outHeightCntI <=0;
      elsif ctrlMainSttI=calcParaStt OR ctrlMainSttI=extraOutStt then
        if outHeightCntI=outNumHeightI then outHeightCntI <=0;
        else outHeightCntI <=outHeightCntI +1; end if;
      end if;
    end if;
  END PROCESS;

  outHeightCntExtraIP : PROCESS(all)
  BEGIN
    if resetB='0' then outHeightCntExtraI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=idleStt OR ctrlMainSttI=waitStartStt then outHeightCntExtraI <=0;
      elsif (convCoreEnd='1' AND to_integer(unsigned(strHeightCnt))=0) OR ctrlMainSttI=extraOutStt then
        if outHeightCntExtraI=maxOutputNum then outHeightCntExtraI <=0;
        else outHeightCntExtraI <=outHeightCntExtraI +1; end if;
      end if;
    end if;
  END PROCESS;

  endOfConv2DIP : PROCESS(all)
  BEGIN
    if resetB='0' then endOfConv2DI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=restStt then endOfConv2DI <='1';
      elsif ctrlMainSttI=chkEndStt then
        if to_integer(unsigned(numOfStride))=1 then
          if outHeightCntI=outNumHeightI then
            if outAccumLast='0' then endOfConv2DI <='1';
            else endOfConv2DI <='0'; end if;
          else endOfConv2DI <='0'; end if;
        else
          if actualOutCntI=to_integer(unsigned(numOutHeight)) then
            if outAccumLast='0' then endOfConv2DI <='1';
            else endOfConv2DI <='0'; end if;
          else endOfConv2DI <='0'; end if;
        end if;
      else endOfConv2DI <='0'; end if;
    end if;
  END PROCESS;

  extraOutEnP : PROCESS(all)
  BEGIN
    if resetB='0' then extraOutEnI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=extraOutStt then extraOutEnI <='1';
      else                             extraOutEnI <='0'; end if;
    end if;
  END PROCESS;

  strWidthCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then strWidthCntI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=idleStt OR ctrlMainSttI=waitStartStt then strWidthCntI <=0;
      elsif convCoreValid='1' then
        if strWidthCntI=to_integer(unsigned(numOfStride)-1) then strWidthCntI <=0;
        else strWidthCntI <=strWidthCntI +1; end if;
      end if;
    end if;
  END PROCESS;
  strHeightCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then strHeightCntI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=idleStt OR ctrlMainSttI=waitStartStt then strHeightCntI <=0;
      elsif convCoreEnd='1' then
        if strHeightCntI=to_integer(unsigned(numOfStride)-1) then strHeightCntI <=0;
        else strHeightCntI <=strHeightCntI +1; end if;
      end if;
    end if;
  END PROCESS;
  strWidthEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then strWidthEnI <='0';
    elsif rising_edge(clk) then
      if strWidthCntI=0 then strWidthEnI <='1';
      else                   strWidthEnI <='0'; end if;
    end if;
  END PROCESS;
  strHeightEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then strHeightEnI <='0';
    elsif rising_edge(clk) then
      if strHeightCntI=0 then strHeightEnI <='1';
      else                    strHeightEnI <='0'; end if;
    end if;
  END PROCESS;
  actualOutCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then actualOutCntI <=0;
    elsif rising_edge(clk) then
      if ctrlMainSttI=idleStt OR ctrlMainSttI=waitStartStt then actualOutCntI <=0;
      elsif convCoreEnd='1' AND to_integer(unsigned(strHeightCnt))=0 then
        if actualOutCntI=to_integer(unsigned(numOutHeight)) then actualOutCntI <=0;
        else actualOutCntI <=actualOutCntI +1; end if;
      end if;
    end if;
  END PROCESS;
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  isFirstI <='0';
  obRegFileCntIP : PROCESS(all)
  BEGIN
    if resetB='0' then obRegFileCntI <=0;
    elsif rising_edge(clk) then
      obRegFileCntI <=actualOutCntI;
    end if;
  END PROCESS;
  obRegFileWrEnIP : PROCESS(all)
  BEGIN
    if resetB='0' then obRegFileWrEnI <='0';
    elsif rising_edge(clk) then
      if ctrlMainSttI=idleStt OR ctrlMainSttI=waitStartStt then obRegFileWrEnI <='0';
      elsif convCoreEnd='1' AND to_integer(unsigned(strHeightCnt))=0 then
        obRegFileWrEnI <='1';
      else
        obRegFileWrEnI <='0';
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
