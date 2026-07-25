classdef DCDCConverterBoard < handle
    %DCDCConverterBoard: functions to deal with a DCDC Converter Version 2.0
    
    properties
        SiC450 PMBusDev; %two DC/DC converters
        mbc = MBC_TB.empty; %MBC
        offset;             %I2C Addr Offset of the Board
        MPaddr = 0xE0;      %Address of I2C Multiplexer (set to 0 if there is no)
        cOn = 0x04;         %Command to switch I2C channel on
        cOff = 0x00;        %Command to switch I2C channel off
        debug = 0;
        status = 0;
        lastErrorMsg = "";
        UUID = "";
        versionErrorReported = 0;
        nChannels = 0;
    end
    
    methods
        function this = DCDCConverterBoard(MPaddr, cOn, cOff)
            this.offset = 0;
            this.MPaddr = MPaddr;
            this.cOn = cOn;
            this.cOff = cOff;
        end
        function switchOff(this)
            if this.status
                try
                    this.switchVDC(1, 0);
                    this.switchVDC(2, 0);
                    this.switchStatusLED_DCDC(0);
                    %fprintf("DC/DC Converter switched Off. Offset: %d\n", this.offset);
                catch
                end
            end
        end
        function ret = Connect(this, mbc, offset)
            ret = 0;
            this.mbc = mbc;
            this.offset = offset;
            %check software version of ATtiny
            try
                this.mbc.resetI2C();
                ver = this.getSWVersion();
                if ver(1) < 2
                    this.lastErrorMsg = sprintf("Cannot connect to DC/DC Converter: current software version (%d.%d.%d) must be updated to at least version 2.0.0.", ver(1), ver(2), ver(3));
                    this.versionErrorReported = min(this.versionErrorReported + 1, 10);
                    return
                else
                    this.versionErrorReported = 0;
                end
                this.status = 0;
                %DC/DC Converter Board 2.0
                this.SiC450(1)=PMBusDev(this.mbc,0x38,offset,this.MPaddr,this.cOn,this.cOff);
                this.SiC450(1).Init();
                this.switchVDC(1, 0);
                this.nChannels = 1;
                this.status = 1;
                %A Board with at least one channel is connected
                ret = 1;
                %DC/DC Converter Board 2.0
                I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
                if mbc.checkI2CAddr(0x3A, this.offset, 2)
                    this.SiC450(2)=PMBusDev(this.mbc,0x3A,offset,this.MPaddr,this.cOn,this.cOff);
                    this.SiC450(2).Init();
                    this.switchVDC(2, 0);
                    this.nChannels = 2;
                    %A Board with two channels is connected
                    ret = 2;
                end
                this.switchStatusLED_DCDC(1);
                this.UUID = this.getUUIDString();
                this.status = 1;
            catch exc
                this.lastErrorMsg = exc.message;
            end
        end
        function ret = UpdateRefToMBC(this, mbc)
            ret = 0;
            this.mbc = mbc;
            if size(this.SiC450, 1) > 1
                for i=1:1:2
                    if ~isempty(this.SiC450(i)) && isvalid(this.SiC450(i))
                        this.SiC450(i).UpdateRefToMBC(mbc);
                    end
                end
            end
            ret = 1;
        end
        function ret = switchVDC(this, VDC, v)
            ret = 0;
            if VDC > this.nChannels
                return
            end
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            %switch ATtiny: 0-off, 1-on, 2-blink
            this.mbc.writeBytesI2C(0x08, this.offset, [(127+VDC) uint8(v)]);
            if v == 2
                v = 1;
            end
            %switch Sic450
            this.SiC450(VDC).SwitchPWR(v);
        end
        function status = getVDCswitchStatus(this, VDC)
            status = 0;
            if VDC > this.nChannels
                return
            end
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            status = this.mbc.queryBytesI2C(0x08, this.offset, (127+VDC), 1, 1);
        end
        function ret = setFrequDuty(this, f, duty)
            ret = 0;
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            this.mbc.writeBytesI2C(0x08, this.offset, [130 uint8(f*10) duty]);
        end
        function ret = setFrequDutyBank(this, n, f, duty)
            ret = 0;
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            this.mbc.writeBytesI2C(0x08, this.offset, [133+n uint8(f*10) duty]);
        end
        function ret = switchStatusLED_DCDC(this, v)
            ret = 0;
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            %switch ATtiny
            this.mbc.writeBytesI2C(0x08, this.offset, [131 v]);
        end
        
        function ret = setSiC450_Defaults(this, VDC)
            ret = 0;
            if VDC > this.nChannels
                return
            end
            if this.debug 
                fprintf('>>> Set Defaults for VDC: %d\n', VDC);
            end
            %For testing
            if this.debug
                val = this.SiC450(VDC).getON_OFF_CONFIGURATION();
                fprintf('ON_OFF_CONFIGURATION = 0x%X (0b%s)\n', val, dec2bin(val));
                val = this.SiC450(VDC).getOPERATION();
                fprintf('OPERATION = 0x%X (0b%s)\n', val, dec2bin(val));
                val = this.SiC450(VDC).getVOUT_COMMAND();
                fprintf('VOUT = %f\n', val);
            end
            this.SiC450(VDC).setCLEAR_FAULTS();
            %allow writing to all registers
            this.SiC450(VDC).setWRITE_PROTECT(0b00000000);
            %OFF
            this.SiC450(VDC).setOPERATION(0x08);
            %react on EN pin and OPERATATION command
            this.SiC450(VDC).setON_OFF_CONFIGURATION(0b00011111);
            %tested for best stability, lowest ripple, highest efficiency
            this.SiC450(VDC).setFREQUENCY_SWITCH(1000);
            
%             this.SiC450(VDC).setTON_MAX_FAULT_LIMIT(100);
%             this.SiC450(VDC).setTON_DELAY(0);
%             this.SiC450(VDC).setTON_RISE(0);

            %set to recommended value for VOUT = 5 V, is kept constant according to Vishay support
            %VOUT_OV protection does not work if VOUT_SCALE_LOOP is adapted to VOUT
            this.SiC450(VDC).setVOUT_SCALE_LOOP(0xE802);

            %Switch off reaction on VIN Over Voltage 
            this.SiC450(VDC).setVIN_OV_FAULT_RESPONSE(0);

            this.SiC450(VDC).setVIN_OV_FAULT_LIMIT(24);
            %this.SiC450(VDC).getVIN_OV_FAULT_LIMIT();
            %this.SiC450(VDC).setVIN_UV_FAULT_LIMIT(9); %not supported by SiC450
            this.SiC450(VDC).setVIN_UV_WARN_LIMIT(8);
            
            this.SiC450(VDC).setVOUT_OV_FAULT_LIMIT(5.5);
            %this.SiC450(VDC).getVOUT_OV_FAULT_LIMIT();
            this.SiC450(VDC).setVOUT_OV_WARN_LIMIT(5.4);
            
            %this.SiC450(VDC).getVOUT_UV_FAULT_LIMIT();
            this.SiC450(VDC).setVOUT_UV_FAULT_LIMIT(1.6);
            %this.SiC450(VDC).getVOUT_UV_FAULT_LIMIT();
            
            %this.SiC450(VDC).getVOUT_UV_WARN_LIMIT();
            this.SiC450(VDC).setVOUT_UV_WARN_LIMIT(1.7);
            %this.SiC450(VDC).getVOUT_UV_WARN_LIMIT();
            
            this.SiC450(VDC).setVOUT_UV_FAULT_RESPONSE(0b00000000);
            %this.SiC450(VDC).setVOUT_UV_FAULT_RESPONSE(0b00010110);
            %this.SiC450(VDC).setVOUT_UV_FAULT_RESPONSE(0b00100010);
            %this.SiC450(VDC).setVOUT_UV_FAULT_RESPONSE(0b00110110);
            %this.SiC450(VDC).getVOUT_UV_FAULT_RESPONSE();
            
            %this.SiC450(VDC).getVOUT_MARGIN_LOW();
            this.SiC450(VDC).setVOUT_MARGIN_LOW(1.6);
            %this.SiC450(VDC).getVOUT_MARGIN_LOW();
            
            %this.SiC450(VDC).getVOUT_MARGIN_HIGH();
            this.SiC450(VDC).setVOUT_MARGIN_HIGH(5.4);
            %this.SiC450(VDC).getVOUT_MARGIN_HIGH();
            
            %this.SiC450(VDC).getPOWER_GOOD_ON();
            this.SiC450(VDC).setPOWER_GOOD_ON(1.6);
            %this.SiC450(VDC).getPOWER_GOOD_ON();
            
            %this.SiC450(VDC).getPOWER_GOOD_OFF();
            this.SiC450(VDC).setPOWER_GOOD_OFF(1.7);
            %this.SiC450(VDC).getPOWER_GOOD_OFF();
            
            %this.SiC450(VDC).getTON_RISE();
            this.SiC450(VDC).setTON_RISE(10);
            
            %this.SiC450(VDC).getTON_MAX_FAULT_LIMIT();
            this.SiC450(VDC).setTON_MAX_FAULT_LIMIT(100);
            
            this.SiC450(VDC).setCLEAR_FAULTS();
            
            this.SiC450(VDC).setVOUT_COMMAND(3.0);
            
            %allow writing to  WRITE_PROTECT, OPERATION, ON_OFF_CONFIG and VOUT_COMMAND commands
            %this.SiC450(VDC).setWRITE_PROTECT(0b00100000);
            
            %TODO: check status
            ret = 1;
        end
        function ret = setSiC450_StoreDefaults(this, VDC)
            ret = 0;
            if VDC > this.nChannels
                return
            end
            this.SiC450(VDC).setWRITE_PROTECT(0x00);
            this.SiC450(VDC).setEEPROM_PASSWORD([0x12, 0x34]);
            this.SiC450(VDC).setSTORE_USER_ALL();
            %this.SiC450(VDC).setWRITE_PROTECT(0b00100000);
            %TODO: check status
            ret = 1;
        end
        function ret = setSiC450_Voltage(this, VDC, v)
            ret = 0;
            if VDC > this.nChannels
                return
            end
            %sets VOUT of VDC, adapts VOUT_SCALE_LOOP, VOUT_OV_FAULT_LIMIT and VOUT_UV_FAULT_LIMIT
            scale = uint16(0xE802);
            VOUT_UV_F = 1.6;
            VOUT_OV_F = 5.5;
            VOUT_UV_W = 1.5;
            VOUT_OV_W = 5.4;
            PGOOD_ON = 0.3;
            PGOOD_OFF = 0.28;
            if v>5.5
                v = 5.5;
            end
            if((v < 1.8))
            %if((1.79 <= v) && (v < 3.3))
                scale = 0xE804;
                VOUT_UV_F = 0.28;
                VOUT_OV_F = 3.6;
                VOUT_UV_W = 0.3;
                VOUT_OV_W = 3.5;
                PGOOD_ON = 0.3;
                PGOOD_OFF = 0.28;
%             elseif(v < 1.8)
%                 scale = 0xE808;
%                 VOUT_UV_F = 0.28;
%                 VOUT_OV_F = 2.5;
%                 VOUT_UV_W = 0.29;
%                 VOUT_OV_W = 2.2;
%                 PGOOD_ON = 1.62;
%                 PGOOD_OFF = 1.53;
            end
            on = 0;
            if scale ~= this.SiC450(VDC).getVOUT_SCALE_LOOP()
                op = this.SiC450(VDC).getOPERATION();
                on = bitget(op, 8);
                if on
                    %switch off in case VOUT_SCALE_LOOP must be set to new values
                    %TODO: check if really necessary: 2024-02-02: Yes, if
                    %the change is done downwards with certain loads,
                    %sometimes oscilations in VDC occur
                    this.SiC450(VDC).setOPERATION(0b00001000);
                end
                this.SiC450(VDC).setVOUT_SCALE_LOOP(scale);
                this.SiC450(VDC).setVOUT_UV_WARN_LIMIT(VOUT_UV_W);
                this.SiC450(VDC).setVOUT_UV_FAULT_LIMIT(VOUT_UV_F);
                this.SiC450(VDC).setVOUT_OV_WARN_LIMIT(VOUT_OV_W);
                this.SiC450(VDC).setVOUT_OV_FAULT_LIMIT(VOUT_OV_F);
                this.SiC450(VDC).setVOUT_MARGIN_LOW(VOUT_UV_F);
                this.SiC450(VDC).setVOUT_MARGIN_HIGH(VOUT_OV_F);
                this.SiC450(VDC).setPOWER_GOOD_ON(PGOOD_ON);
                this.SiC450(VDC).setPOWER_GOOD_OFF(PGOOD_OFF);
                
%                 this.SiC450(VDC).getVOUT_UV_WARN_LIMIT();
%                 this.SiC450(VDC).getVOUT_UV_FAULT_LIMIT();
%                 this.SiC450(VDC).getVOUT_MARGIN_LOW();
%                 this.SiC450(VDC).getPOWER_GOOD_OFF();
%                 
%                 this.SiC450(VDC).getVOUT_OV_WARN_LIMIT();
%                 this.SiC450(VDC).getVOUT_OV_FAULT_LIMIT();
%                 this.SiC450(VDC).getVOUT_MARGIN_HIGH();
%                 this.SiC450(VDC).getPOWER_GOOD_ON();
            end
            this.SiC450(VDC).setVOUT_COMMAND(v);
            if on
                %ON
                this.SiC450(VDC).setOPERATION(0b10001000);
            end
            ret=1;
        end
        function uuid = getUUID(this)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            uuid = zeros(1,16, 'uint8');
            for i=1:1:16
                v = this.mbc.queryBytesI2C(0x08, this.offset, 148+i-1, 1, 1);
                uuid(i) = v(1);
            end
        end
        function ret = setUUID(this, uuid)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            try
                for i=1:1:16
                    ret = this.mbc.writeBytesI2C(0x08, this.offset, [148+i-1 uuid(i)]);
                end
                ret = 1;
            catch e
                fprintf("Something went wrong writing UUID. Check Mainboard!(%s).\n", e.message);
            end
        end
        function str = getUUIDString(this)
            str = '';
            uuid = this.getUUID();
            for i=1:1:16
                str = strcat(str, dec2hex(uuid(i),2));
                if (i==4)||(i==6)||(i==8)||(i==10)
                    str = strcat(str, '-');
                end
            end
        end
        function ret = setUUIDString(this, str)
            ret = 0;
            uuid = zeros(1,16, 'uint8');
            str = regexprep(str,'[-]','');
            if strlength(str) == 32
                for i=1:1:16
                    uuid(i) = hex2dec(str((2*i - 1):(2*i)));
                end
                ret = this.setUUID(uuid);
            else
                ret = 0;
            end
        end
        function ver = getSWVersion(this)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ver = zeros(1,3, 'uint8');
            ver = this.mbc.queryBytesI2C(0x08, this.offset, 255, 1, 3);
        end
        function str = getSWVersionString(this)
            str = '???';
            try
                ver = this.getSWVersion();
                str = sprintf('%d.%d.%d', ver(1), ver(2), ver(3));
            catch
            end
        end
        function ret = setTimer(this, t)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            bytes = zeros(2, 1,'uint8');
            %bytes(1) = uint8(mod(uint16(t), 256));
            %bytes(2) = uint8(bitshift(uint16(t), -8, 'uint16'));
            ret = this.mbc.writeBytesI2C(0x08, this.offset, [128 + 4 uint8(mod(uint16(t), 256)) uint8(bitshift(uint16(t), -8, 'uint16'))]);
        end
        function ret = getTimer(this)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            bytes = zeros(1,2, 'uint8');
            bytes = this.mbc.queryBytesI2C(0x08, this.offset, 128 + 4, 1, 2);
            ret = uint16(bytes(2)) * 256 + uint16(bytes(1));
        end
        function ret = setATtinyStatus(this, s)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            ret = this.mbc.writeBytesI2C(0x08, this.offset, [128 + 5 uint8(s)]);
        end
        function ret = getATtinyStatus(this)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            bytes = uint8(0);
            bytes = this.mbc.queryBytesI2C(0x08, this.offset, 128 + 5, 1, 1);
            ret = bytes(1);
        end
        function switchOn(this, VDC1, VDC2, f1, f2, dutyCycle1, dutyCycle2, duration)
            mode1 = 1;
            mode2 = 1;
            if f1 > 0
                this.setFrequDutyBank(1, f1, dutyCycle1);
                mode1 = 2;
            end
            if f2 > 0
                this.setFrequDutyBank(2, f2, dutyCycle2);
                mode2 = 2;
            end
            if VDC1 > 0.0
                this.setSiC450_Voltage(1, VDC1);
            else
                %Do not switch on, if voltage is 0
                mode1 = 0;
            end
            if this.nChannels > 1
                if VDC2 > 0
                    this.setSiC450_Voltage(2, VDC2);
                else
                    %Do not switch on, if voltage is 0
                    mode2 = 0;
                end
            end
            this.setTimer(duration);
            this.switchVDC(1, mode1);
            this.switchVDC(2, mode2);
        end
        function status = checkSiC450(this)
            status = false;
            %fix for issue #12: sometimes a timeout happens
            %we check 10 times and return after 1st success
            for i=1:1:10
                try
                    this.SiC450(1).getSTATUS_WORD();
                    if this.nChannels > 1
                        this.SiC450(2).getSTATUS_WORD();
                    end
                    %TODO: check status word!
                    status = true;
                    break;
                catch exc
                    this.lastErrorMsg = exc.message;
                end
            end
        end
    end
end

