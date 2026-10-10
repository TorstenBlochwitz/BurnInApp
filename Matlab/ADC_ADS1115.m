classdef ADC_ADS1115 < handle
    %ADC_ADS1115: Support functions for the AD Converter ADS1115
    properties
        mbc;    %MBC
        address;%I2C address
        offset; %I2C offset of the Board
        debug = 0;
        MPaddr = 0xE0; %Address of I2C Multiplexer
        cOn;    %command to switch I2C channel on
        cOff;   %command to switch I2C channel off
        lastReadRaw = [uint8(0) uint8(0)];
        nRepeat = 5;
    end
    
    methods
        function this = ADC_ADS1115(MBC, address, offset, MPaddr, cOn, cOff)
            this.mbc=MBC;
            this.address = address;
            this.offset = offset;
            this.MPaddr = MPaddr;
            this.cOn = cOn;
            this.cOff = cOff;
        end
        function ret = UpdateRefToMBC(this, mbc)
            ret = 0;
            this.mbc = mbc;
            ret = 1;
        end
        function v = getVoltage(this, configMux, gain)
            v = 0.0;
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            %reads differential voltage between channel 0 and 1
            %adapted from https://github.com/adafruit/Adafruit_ADS1X15
            config = uint16(0);
            config = bitor(config, 0x0003); %ADS1X15_REG_CONFIG_CQUE_1CONV: Disable the comparator and put ALERT/RDY in high state (default)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CLAT_NONLAT: Non-latching (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CPOL_ACTVLOW: Alert/Rdy active low   (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CMODE_TRAD: Traditional comparator (default val)
            config = bitor(config, ADS1115.ADS1X15_REG_CONFIG_MODE_CONTIN);
            config = bitor(config, gain);
            config = bitor(config, 0x0080); %RATE_ADS1115_128SPS (default)
            config = bitor(config, configMux);
            config = bitor(config, 0x8000); %ADS1X15_REG_CONFIG_OS_SINGLE: Set to start a single-conversion
            
            %write to config register
            this.mbc.writeBytesI2C(this.address, this.offset, [0x01 uint8(bitshift(config, -8)) uint8(bitand(config, 0b0000000011111111))]);
            pause(0.5); %This is a try to wait some time before reading            
            raw = this.mbc.queryBytesI2C(this.address, this.offset, 0x00, 1, 2);
            %convert to voltage, considering gain
            v = this.computeVolts(gain, raw);
        end

        function v = getVoltageDiff(this, configMux, gain)
            v = 0.0;

            %v = this.getVoltage(configMux, gain);
            %return

            configMux = ADS1115.CONFIG_MUX_SINGLE_0;

            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            %reads differential voltage between channel 0 and 1
            %adapted from https://github.com/adafruit/Adafruit_ADS1X15
            config = uint16(0);
            config = bitor(config, 0x0003); %ADS1X15_REG_CONFIG_CQUE_1CONV: Disable the comparator and put ALERT/RDY in high state (default)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CLAT_NONLAT: Non-latching (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CPOL_ACTVLOW: Alert/Rdy active low   (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CMODE_TRAD: Traditional comparator (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_MODE_CONTIN: %Continuous conversion mode
            %config = bitor(config, 0x0100); %ADS1X15_REG_CONFIG_MODE_SINGLE: Single Shot Mode (default)
            config = bitor(config, gain);
            config = bitor(config, 0x0080); %RATE_ADS1115_128SPS (default)
            config = bitor(config, configMux);
            %config = bitor(config, 0x8000); %ADS1X15_REG_CONFIG_OS_SINGLE: Set to start a single-conversion
            
            %write to config register
            bytes = [uint8(0x01) uint8(bitshift(config, -8)) uint8(bitand(config, 0b0000000011111111))];
            floating = false;
            for i=1:1:this.nRepeat
                try
                    this.mbc.writeBytesI2C(this.address, this.offset, bytes);
        
                    %check if config arrived corrcetly at ADS1115
                    status = this.mbc.queryBytesI2C(this.address, this.offset, 0x01, 1, 2);
                    if ~isequalmask(status, [bytes(2) bytes(3)], [0b11111111 0b11111110])
                        %fprintf('Problem1 in ADC: Incorrect config register\n');
                        this.mbc.CBerror('029');
                    end
                    %wait until conversion is complete
                    pause(0.1);
                    %read conversion result
                    raw1 = this.mbc.queryBytesI2C(this.address, this.offset, 0x00, 1, 2);
                    v1 = this.computeVolts(gain, raw1);
                    %read a second time to check if we read correct values
                    raw2 = this.mbc.queryBytesI2C(this.address, this.offset, 0x00, 1, 2);
                    v2 = this.computeVolts(gain, raw2);
                    if(v1 > 5.1) || (v2 > 5.1)
                        floating = true;
                    end
                    %Check if the two measured voltage differ too much             
                    if abs(v1 - v2) < max(0.01, 0.1 * max(abs(v1),abs(v2)))
                        v = (v1 + v2)/2;
                        return
                    else
                        % v1 and v2 differ more than 10%: there might have been a
                        % problem in reading the conversion result or an
                        % indication for a floating input
                        if i == this.nRepeat && floating
                            v = 0.0;
                            return
                        end
                        %fprintf('Problem2 in ADC: Reading the conversion result: v1 = %f v2 = %f\n', v1, v2);
                        this.mbc.CBerror('029');
                    end
                    % 1.try: Check abs. difference
                    % if abs(v - vCheck) > 0.1 * abs(v)
                    %     % differs more than 10% there might have been a
                    %     % problem in reading the conversion result
                    %     fprintf('Problem2 in ADC: Reading the conversion result: v = %f vCheck = %f\n', v, vCheck);
                    %     this.mbc.CBerror('029');
                    % else
                    %     return
                    % end
                    % Initial try: Check if there was really a reading or if the last
                    % %conversion result was returned
                    % if(isequal(raw1, this.lastReadRaw))
                    %     %fprintf('Problem2 in ADC: No conversion happened\n');
                    %     this.mbc.CBerror('029');
                    % end
                    % %read a second time to check if we read correct values
                    % raw2 = this.mbc.queryBytesI2C(this.address, this.offset, 0x00, 1, 2);
                    % if(~isequal(raw1, raw2))
                    %     %fprintf('Problem3 in ADC: Wrong values read\n');
                    %     this.mbc.CBerror('029');
                    % else
                    %     this.lastReadRaw = raw1;
                    %     %convert to voltage, considering gain
                    %     v = this.computeVolts(gain, raw1);
                    %     return
                    % end
                catch e
                    if this.debug
                        this.mbc.statusFile.addMsg(msgLevel.WARNING, sprintf("Communication problem during ADC measurement"));
                    end
                    if i==this.nRepeat
                        rethrow(e);
                    end
                end
            end
        end

        function v = computeVolts(this, gain, raw)
            switch (gain)
                case ADS1115.GAIN_TWOTHIRDS_6_144
                    fsRange = 6.144;
                case ADS1115.GAIN_ONE_4_096
                    fsRange = 4.096;
                case ADS1115.GAIN_TWO_2_048
                    fsRange = 2.048;
                case ADS1115.GAIN_FOUR_1_024
                    fsRange = 1.024;
                case ADS1115.GAIN_EIGHT_0_512
                    fsRange = 0.512;
                case ADS1115.GAIN_SIXTEEN_0_256
                    fsRange = 0.256;
            end
            v = double(bitshift(uint16(raw(1)), 8) + uint16(raw(2))) * (fsRange / 32768);
            if this.debug
                fprintf('raw = 0x%X 0x%X, v = %f V\n', raw(1), raw(2), v);
            end
        end
    end
end

