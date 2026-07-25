classdef MainBoard < handle
    %MAINBOARD functions to deal with a BurnIn Main Board
  
    properties
        mbc = MBC_TB.empty;      %MBC
        offset;   %I2C Addr offset of the Board
        debug = 0;
        status = 0;
        lastErrorMsg = "";
        MPaddr = 0xE0; %Address of I2C Multiplexer (set to 0 if there is no)
        cOn = 0x04;         %Command to switch channel on
        cOff = 0x00;        %Command to switch channel off
        adc;    %AD Converter ADS1115
        EEPROM; %M24C02
        tempSensor TempSensor_TMP1075;
        RShunt = 0.82;
        PShuntMax = 0.4;
        UUID = "";
        brightnessPosLEDs = 20; %in percent;
        brightnessStatusLEDs = 20; 
        %color of status LEDs
        rgbLEDstatus1 = [0.0 0.0 0.0];
        rgbLEDstatus2 = [0.0 0.0 0.0];
        rgbLEDstatus3 = [0.0 0.0 0.0];
        statusLED = false; %D1 at P17 of D1 (PCF8575DWR)
        %reading the status of PCF8575DWR is not safe because the pins
        %switch to input mode. For that reason, we store the status here:
        statusPCF8575DWR = [uint8(0xFF), uint8(0xFF)];
        mainBoardKind MainBoardKind;
    end
    
    methods
        function this = MainBoard(MPaddr, cOn, cOff)
            this.offset = 0;
            this.MPaddr = MPaddr;
            this.cOn = cOn;
            this.cOff = cOff;
            this.lastErrorMsg = "";
        end
        function ret = Connect(this, mbc, offset, mainBoardKind)
            this.mbc=mbc;
            this.offset = offset;
            this.mainBoardKind = mainBoardKind;
            try
                this.status = 0;
                %Reset I2C (due to hot plug, something might have happened!)
                this.mbc.resetI2C();
                %check existance
                this.switchStatusLED(1);
                %switch off analog multiplexer
                this.setMUX(-1);
                this.adc = ADC_ADS1115(this.mbc, 0x90, offset, this.MPaddr, this.cOn, this.cOff);
                this.EEPROM = EEPROM_M24C02(this.mbc, 0xA0, offset, this.MPaddr, this.cOn, this.cOff);
                this.tempSensor(1) = TempSensor_TMP1075(this.mbc, 0x94, this.offset, this.MPaddr, this.cOn, this.cOff);
                this.tempSensor(2) = TempSensor_TMP1075(this.mbc, 0x98, this.offset, this.MPaddr, this.cOn, this.cOff);
                this.tempSensor(3) = TempSensor_TMP1075(this.mbc, 0x9C, this.offset, this.MPaddr, this.cOn, this.cOff);
                
                this.UUID = this.EEPROM.getUUIDString();

                this.status = 1;
            catch exc
                this.lastErrorMsg = exc.message;
            end
            ret = this.status;
        end
        function ret = UpdateRefToMBC(this, mbc)
            ret = 0;
            this.mbc = mbc;
            if ~isempty(this.adc) && isvalid(this.adc)
                this.adc.UpdateRefToMBC(mbc);
            end
            if ~isempty(this.EEPROM) && isvalid(this.EEPROM)
                this.EEPROM.UpdateRefToMBC(mbc);
            end
            if size(this.tempSensor, 1) > 1
                for i=1:1:3
                    if ~isempty(this.tempSensor(i)) && isvalid(this.tempSensor(i))
                        this.tempSensor(i).UpdateRefToMBC(mbc);
                    end
                end
            end
            ret = 1;
        end
        function status = checkMainBoard(this)
            status = false;
            try
                this.setMUX(-1);
                status = true;
            catch exc
                this.lastErrorMsg = exc.message;
            end
        end
        function ret = switchStatusLED(this, v)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            %Current status of PCF8575DWR
            bytes = this.statusPCF8575DWR;
            if this.debug
                val = uint16(bytes(1))*256+uint16(bytes(2));
                fprintf('cur MUX = 0x%X (0b%s)\n', val, dec2bin(val));
            end
            %set bit 8, which correlates to P17
            if v == 1
                bytes(2)=bitset(bytes(2),8,0);
                if this.debug 
                    fprintf('LED: On\n');
                end
                ret = 1;
            else
                bytes(2)=bitset(bytes(2),8,1);
                if this.debug 
                    fprintf('LED: Off\n');
                end
            end
            %this.mbc.writeBytesI2C(0x40, this.offset, bytes);
            ret = this.writeMuxSafely(bytes);
            this.statusLED = v > 0;
            this.statusPCF8575DWR = bytes;
        end
   
        function ret = setMUX(this, pos)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            if pos < 0
                %disable all MUX channels
                %set all bits except LED (P17) to 1 
                bytes(1) = uint8(0xFF);
                bytes(2) = bitset(uint8(0xFF), 8, ~this.statusLED);
                if this.debug
                    val = uint16(bytes(2))*256+uint16(bytes(1));
                    fprintf('bytes = 0x%X (0b%s)\n', val, dec2bin(val));
                end
            else
                %set A0..A7 (P00..P07), bits 9..16
                bytes(1) = uint8(pos);
                %enable EN_GND (P10)
                bytes(2) = bitset(uint8(0xFF), 1, 0);
                %keep LED (P17)
                bytes(2) = bitset(bytes(2), 8, ~this.statusLED);
                if this.debug
                    val = uint16(bytes(2))*256+uint16(bytes(1));
                    fprintf('bytes = 0x%X (0b%s)\n', val, dec2bin(val));
                end
            end
            %this.mbc.writeBytesI2C(0x40, this.offset, bytes);
            ret = this.writeMuxSafely(bytes);
            %store the values in status after sending to ensure it is the
            %correct value in case an exception was thrown
            this.statusPCF8575DWR = bytes;
            ret = 1;
        end

        function ret = writeMuxSafely(this, bytes)
            ret = 0;
            attempts = 10; %max. number of attempts
            for i=1:1:attempts
                this.mbc.writeBytesI2C(0x40, this.offset, bytes);
                % check read stability
                read1 = this.mbc.readBytesI2C(0x40, this.offset, 2);
                read2 = this.mbc.readBytesI2C(0x40, this.offset, 2);
                if ~isequal(read1, read2)
                    continue
                end
                %check returned value
                if isequal(read2, bytes)
                    ret = 1;
                    if i>1
                        fprintf('setMux retried\n');
                    end
                    break
                end
            end
            if ret==0
                fprintf('Problem setting MUX\n');
            end
        end

        function ret = switchRGBLED(this, index, R, G, B, switchOffLEDs, setLEDs)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            index = max(1, index);
            if index == 26
                index = 125;
            end

            %keep status RGB LEDs at current color
            rgb = [this.rgbLEDstatus1; this.rgbLEDstatus2; this.rgbLEDstatus3]; 
            if switchOffLEDs
                if this.mainBoardKind > MainBoardKind.FullBoardWithATtiny
                    iStatusLEDstart = 59;
                else
                    iStatusLEDstart = 119;
                end
                for i=1:1:3
                    this.mbc.writeBytesI2C(0x08, this.offset, [uint8(iStatusLEDstart + i) uint8(rgb(i, 1) * this.brightnessStatusLEDs / 100) uint8(rgb(i, 2) * this.brightnessStatusLEDs / 100) uint8(rgb(i, 3) * this.brightnessStatusLEDs/ 100) uint8(switchOffLEDs) uint8(false)]);
                    switchOffLEDs = false;
                end
            end
            % if ~ispc
            %     pause(0.1);
            % end
            %during testing, sometimes the MBC returned an error because of
            %missing I2C ACK signal. Let's try again maximum 10 times
            this.mbc.writeBytesI2C(0x08, this.offset, [uint8(index-1) uint8(R * this.brightnessPosLEDs / 100) uint8(G * this.brightnessPosLEDs / 100) uint8(B * this.brightnessPosLEDs / 100) uint8(switchOffLEDs) uint8(setLEDs)]);
            if ~ispc
                pause(0.1);
            end
            ret = 1;
        end
        function switchRGBLEDs(this, bSwitch, R, G, B)
            last = 0;
            %Backwards should go faster
            for i=size(bSwitch,2):-1:1
                if bSwitch(i)
                    last = i;
                    break;
                end
            end
            for i=1:1:last
                if bSwitch(i)
                    this.switchRGBLED(i, R, G, B, false, last == i);
                end
            end
        end

        function switchOff(this, complete)
            if nargin < 1
                complete = true;
            end
            try
                this.setMUX(-1);
                this.switchStatusLED(0);
                if complete
                    this.switchRGBLED(0, 0, 0, 0, 1, 1);
                    %printf("MainBoard RGB LEDs switched Off. Offset: %d\n", this.offset);
                end
                %fprintf("MainBoard switched Off. Offset: %d\n", this.offset);
            catch
            end
        end
        function switchOn(this)
            this.switchStatusLED(1);
        end
        function v = getVMaxShortCircuit(this)
            %returns maximum voltage for checking for short circuits
            v = sqrt(this.RShunt * this.PShuntMax);
        end
        function setStatusRGBLEDs(this, rgbLEDstatus1, rgbLEDstatus2, rgbLEDstatus3)
            updateNeeded = false;
            if ~isequal(this.rgbLEDstatus1, rgbLEDstatus1)
                updateNeeded = true;
                this.rgbLEDstatus1 = rgbLEDstatus1;
            end
            if ~isequal(this.rgbLEDstatus2, rgbLEDstatus2)
                updateNeeded = true;
                this.rgbLEDstatus2 = rgbLEDstatus2;
            end
            if ~isequal(this.rgbLEDstatus3, rgbLEDstatus3)
                updateNeeded = true;
                this.rgbLEDstatus3 = rgbLEDstatus3;
            end
            if updateNeeded
                if this.mainBoardKind > MainBoardKind.FullBoardWithATtiny
                    iStatusLEDstart = 60;
                else
                    iStatusLEDstart = 120;
                end
                %don't change other RGB LEDs
                this.switchRGBLED(iStatusLEDstart + 1, rgbLEDstatus1(1), rgbLEDstatus1(2), rgbLEDstatus1(3), false, false);
                this.switchRGBLED(iStatusLEDstart + 2, rgbLEDstatus2(1), rgbLEDstatus2(2), rgbLEDstatus2(3), false, false);
                this.switchRGBLED(iStatusLEDstart + 3, rgbLEDstatus3(1), rgbLEDstatus3(2), rgbLEDstatus3(3), false, true);
            end
        end
    end
end

