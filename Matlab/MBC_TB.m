classdef MBC_TB < MBC_USB_TCP
    %MBC_TB Construct a MBC_TB object.
    methods
        function this = MBC_TB(varargin)
            this@MBC_USB_TCP(varargin)
            %We have to distinguish between an MBC which communicates via
            %COM and the Ethernet MBCs
            this.I2CAddresses = {...
            0x08 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %µC ATtiny84A: U3 
            0x38 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %DC/DC Converter for VDC1 SiC450: U1
            0x3A I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %DC/DC Converter for VDC2 SiC450: U2
            0x40 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %16 bit I2C to GPIO PCF8575DWR: IC2
            0x90 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %ADC ADS1115: IC2
            0x92 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %? exists also with deactivated I2C Multiplexer
            0x94 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %Temperature Sensor TMP1075DGKR: IC13
            0x98 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %Temperature Sensor TMP1075DGKR: IC10
            0x9C I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %Temperature Sensor TMP1075DGKR: IC11
            0xA0 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %EEPROM M24C02 (Memory access): IC3
            0xB0 I2CAddrProp.DONT_USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %EEPROM M24C02 (Identification page access): IC3
            0xE0 I2CAddrProp.USE_OFFSET I2CAddrProp.DONT_USE_OFFSET;...    %I2C Multiplexer PCA9542APW: IC9
            };
            this.Timeout = 2;
            this.addrOffset = 0;
            this.closeFlag = 0;
            this.DUTi2cEnable = 0;
            this.version = this.getVersion();
        end
 
        
        %check for response at addr, offset
        function ret = checkI2CAddr(this, addr, offset, nRepeat)
            if nargin < 4
                nRepeat = this.nRepeat;
            end
            %check if MBC is still connected by asking for version
            this.getVersion();
            
            this.switchI2C(0);

            [I2Caddr, ] = this.adaptAddr(addr, offset);
            msg = ['IR_',dec2hex(I2Caddr,2),'001'];
            %msg = ['IR_',dec2hex(I2Caddr,2),'001',13];
            %msg = ['ir_',dec2hex(I2Caddr,2),'001',13];
            for i=1:1:nRepeat
                try
                    resp = this.writeMessage(msg, offset);
                    if length(resp)~=3
                        ret = true;
                        return;
                    end
                catch e
                    if this.debug
                        if offset == 0
                            strAddr = sprintf("0x%X", addr);
                        else
                            strAddr = sprintf("0x%X, offset = %d", addr, offset);
                        end
                        this.statusFile.addMsg(msgLevel.WARNING, sprintf("%d. I2C communication problem in checkI2CAddr: %s\naddr = %s, msg = %s\n", i, e.message, strAddr, msg));  
                    end
                    if i==nRepeat
                        ret = false;
                        return;
                    end
                end
            end
            ret = false;
            return;
        end

        function setI2Cfrequency(this,v)
            if v<10
                msg = ['IS_' sprintf('0%d', v)];
            else
                msg = ['IS_' sprintf('%d', v)];
            end
            this.writeSerial(msg);
        end
    end
    
    methods(Access = protected)
        %overwritten function of base class to repeat sending in case of
        %an error due to timing
        function switchI2C(this,port)
            % switch between internal and DUT port
            % 0: internal (control bus)
            % 1: DUT
            if this.mode == MBCModeEnum.I2C
                %not supported in version 2
                if str2num(this.version(2:strfind(this.version(2:4),'.'))) == 2
                    return
                end
    
                if ~this.DUTi2cEnable
                    port = 0;
                end
                
                % set i2c to internal
                if port
                    msg = 'PS_E21';
                else
                    msg = 'PS_E20';
                end
                for i=1:1:this.nRepeat
                    try
                        resp = this.writeSerial(msg);
                
                        if ~isempty(resp)
                            this.CBerror(resp);
                        else
                            break;
                        end
                    catch e
                        fprintf("%d. I2C communication problem in switchI2C: %s\nmsg = %s\n", i, e.message, msg);
                        if i==this.nRepeat
                            rethrow(e);
                        end
                    end
                end
            end
        end
    end
end