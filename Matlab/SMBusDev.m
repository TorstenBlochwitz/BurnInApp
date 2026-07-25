classdef SMBusDev < handle
    %SMBUSDEV: basic support functions to control a SMBus Device
    
    properties
        mbc;         %MBC_TB
        addr;        %I2C Address of the device
        offset;      %used for I2C Multiplexer only
        MPaddr;      %Address of I2C Multiplexer (set to 0 if there is no)
        cOn;         %Command to switch channel on
        cOff;        %Command to switch channel off
        leastByteFirst; %Some SMBus devices expect the least significant byte first, some not
        connected;
    end
    
    methods
        function this = SMBusDev(MBC, addr, offset, MPaddr, cOn, cOff, leastByteFirst)
            this.addr = addr;
            this.mbc = MBC;
            this.offset = offset;
            this.MPaddr = MPaddr;
            this.cOn = cOn;
            this.cOff = cOff;
            this.leastByteFirst = leastByteFirst;
            
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            this.connected = this.mbc.checkI2CAddr(addr, this.offset, 2);
        end
        function ret = UpdateRefToMBC(this, mbc)
            ret = 0;
            this.mbc = mbc;
            ret = 1;
        end
        function ret = readBytes(this, cmd, n)
            %sends cmd, reads bytes
            %PEC is received, but ignored
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            bytes = this.mbc.queryBytesI2C(this.addr, this.offset, cmd, 1, n + 1);
            %bytes=[0,0,0];
            if n == length(bytes) - 1
                for index = 1:n
                    if this.leastByteFirst
                        ret(index) = uint8(bytes(length(bytes) - index));
                    else
                        ret(index) = uint8(bytes(index));
                    end
                end
            end
        end
        
        function ret = readWord(this, cmd)
            %sends cmd, reads one word
            ret = 0;
            bytes = this.readBytes(cmd, 2);
            if 2 == length(bytes)
                ret = bitshift(uint16(bytes(1)), 8) + uint16(bytes(2));
            end
        end
        
        function ret = writeBytes(this, cmd, bytes)
            if ~this.connected
                ret = 0;
                return;
            end
            %writes bytes, followed by PEC (packet error checking) to the I2C bus
            I2Cmulti = I2CMultiplexerPCA9542A(this.mbc, this.offset, this.MPaddr, this.cOn, this.cOff);
            ret = 1;
            %build message
            msg = [this.addr, cmd];
            for index = 1:length(bytes)
                %least significant byte must be sent first
                if this.leastByteFirst
                    msg(2 + index) = bytes(length(bytes) + 1 - index);
                else
                    msg(2 + index) = bytes(bytes(index));
                end
            end
            %compute and append PEC
            msg(2 + length(bytes) + 1) = crc8(msg);
            %fprintf("writeBytes:\n");
            %fprintf("0x%X \n", msg(2:length(msg)));
            %send
            try
                this.mbc.writeBytesI2C(this.addr, this.offset, msg(2:length(msg)));
            catch e
                %fprintf('Send command to SMBus/PMBus device failed: 0x%X: 0x%X \n%s\n', cmd, bytes, e.message);
                ret = 0;
            end                
        end
        
        function ret = blockWriteBytes(this, cmd, bytes)
            if ~this.connected
                ret = 0;
                return;
            end
            %block writes bytes, according to PMBus specification. Size of
            %bytes which will be sent must be sent first. writeBytes() turns
            %the sequence around
            ret = this.writeBytes(cmd, [bytes length(bytes)]);
        end
        
        function ret = writeWord(this, cmd, w)
            if ~this.connected
                ret = 0;
                return;
            end
            %writes w, followed by PEC (packet error checking) to the I2C bus
            ret = this.writeBytes(cmd, [uint8(bitshift(w, -8)) uint8(bitand(w, 0b0000000011111111))]);
        end
    end
end

