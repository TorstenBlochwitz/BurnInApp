classdef EEPROM_M24C02 < handle
    %EEPROM_M24C02 for storing UUID and other data in BurnIn application
    %   Detailed explanation goes here
    
    properties
        mbc;      %MBC
        address;%I2C address
        offset; %I2C Addr of the Board
        debug = 1;
        MPaddr = 0xE0; %Address of I2C Multiplexer
        cOn;    %command to switch I2C channel on
        cOff;   %command to switch I2C channel off
    end
    
    methods
        function this = EEPROM_M24C02(MBC, address, offset, MPaddr, cOn, cOff)
            %TODO: handle offset for EEPROM correctly!
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
        function uuid = getUUID(this)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            uuid = zeros(1,16, 'uint8');
            for i=1:1:16
                v = this.mbc.queryBytesI2C(this.address, this.offset, i-1, 1, 1);
                uuid(i) = v(1);
            end
        end
        function ret = setUUID(this, uuid)
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 0;
            try
                for i=1:1:16
                    ret = this.mbc.writeBytesI2C(this.address, this.offset, [i-1 uuid(i)]);
                end
                ret = 1;
            catch e
                fprintf("Something went wrong writing to EEPROM. Check write access jumper!!(%s).\n", e.message);
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
    end
end

