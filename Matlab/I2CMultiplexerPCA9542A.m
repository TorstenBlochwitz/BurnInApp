classdef I2CMultiplexerPCA9542A < handle
    %I2CMULTIPLEXERPCA9542A: simplfies safe handling of I2C channel
    %switching
    %The channel is switched On in constructor and switched Off in
    %destructor. This makes sure that even in case of an exception, the
    %channel is switched off
    
    properties
        mbc = MBC_TB.empty;      %MBC
        offset; %I2C Addr of the Board
        debug = 1;
        MPaddr = 0xE0; %Address of I2C Multiplexer
        cOn;    %command to switch I2C channel on
        cOff;   %command to switch I2C channel off
    end
    
    methods
        function this = I2CMultiplexerPCA9542A(MBC, offset, MPaddr, cOn, cOff)
            this.mbc=MBC;
            this.offset = offset;
            this.MPaddr = MPaddr;
            this.cOn = uint8(cOn);
            this.cOff = uint8(cOff);
            
            %switch channel On in constructor
            if ~isempty(this.mbc) && this.MPaddr ~= 0
                this.mbc.writeBytesI2CCheck(this.MPaddr, this.offset, this.cOn, 0x07);
            end
        end
        
        function delete(this)
            %switch channel Off in destructor
            try
                if ~isempty(this.mbc) && this.MPaddr ~= 0
                    this.mbc.writeBytesI2CCheck(this.MPaddr, this.offset, this.cOff, 0x07);
                end
            catch
            end
            %fprintf("I2C Multiplexer switched off\n");
        end
    end
end

