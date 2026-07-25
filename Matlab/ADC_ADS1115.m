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

            v = this.getVoltage(configMux, gain);
            return

            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            %reads differential voltage between channel 0 and 1
            %adapted from https://github.com/adafruit/Adafruit_ADS1X15
            config = uint16(0);
            config = bitor(config, 0x0003); %ADS1X15_REG_CONFIG_CQUE_1CONV: Disable the comparator and put ALERT/RDY in high state (default)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CLAT_NONLAT: Non-latching (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CPOL_ACTVLOW: Alert/Rdy active low   (default val)
            config = bitor(config, 0x0000); %ADS1X15_REG_CONFIG_CMODE_TRAD: Traditional comparator (default val)
            config = bitor(config, 0x0100); %ADS1X15_REG_CONFIG_MODE_SINGLE: Single Shot Mode (default)
            config = bitor(config, gain);
            config = bitor(config, 0x0080); %RATE_ADS1115_128SPS (default)
            config = bitor(config, configMux);
            config = bitor(config, 0x8000); %ADS1X15_REG_CONFIG_OS_SINGLE: Set to start a single-conversion
            
            %write to config register
            this.mbc.writeBytesI2C(this.address, this.offset, [0x01 uint8(bitshift(config, -8)) uint8(bitand(config, 0b0000000011111111))]);
            %pause(0.1); %This was a try to wait some time before reading
            %the voltage to avoid wrong measurement result during
            %measureVDC during first measurement
            %on one of my MainBoards, but it did not help!
            
            %wait until conversion is complete
            for k=1:10
                status = this.mbc.queryBytesI2C(this.address, this.offset, 0x01, 1, 2);
                if bitand(status(1), 0x80) ~= 0
                    %read result
                    raw = this.mbc.queryBytesI2C(this.address, this.offset, 0x00, 1, 2);
                    %convert to voltage, considering gain
                    v = this.computeVolts(gain, raw);
                    break
                else
                    fprintf("Waiting\n");
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

