classdef PMBusDev < SMBusDev
    %PMBusDev implements the support of PMBus devices via an MBC
    %   tested with Vishay SiC450
    
    properties
       expU16 = -9; %exponent of VOUT related values, expressed in ULINEAR16
       debug = 0;
    end
    
    methods
        function this = PMBusDev(MBC, addr, offset, MPaddr, cOn, cOff)
            this@SMBusDev(MBC, addr, offset, MPaddr, cOn, cOff, 1);
        end
        
        function ret = setCLEAR_FAULTS(this)
            if this.debug 
                st = dbstack;
                fprintf('%s\n', st(1).name);
            end
            ret = this.writeBytes(0x03, []);
        end
        
        function ret = setWRITE_PROTECT(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            %ret = this.writeCmd(0x10, uint8(v), 1);
            ret = this.writeBytes(0x10, uint8(v));
        end
        function ret = getSTATUS_CML(this)
            ret = this.readBytes(0x7E, 1);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function this = getVOUT_MODE(this)
            %reads the exponent of VOUT related values, expressed in ULINEAR16 representation
            vu = this.readBytes(0x20, 1);
            vi = int8(vu);
            mode = bitshift(vu, -5);
            if mode ~= 0
                error('PMBus device does not support ULINEAR16 format for Vout. This is not implemented!');
            end
            vi = bitshift(int8(vi), 3);
            this.expU16 = bitshift(vi, -3);
            if this.debug
                fprintf('VOUT_MODE returned LINEAR16, exp = %f\n', this.expU16);
            end
        end
        function ret = getSTATUS_WORD(this)
            ret = this.readWord(0x79);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = getSTATUS_VOUT(this)
            ret = this.readBytes(0x7A, 1);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = getSTATUS_INPUT(this)
            ret = this.readBytes(0x7C, 1);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = getREAD_VIN(this)
            ret = 0.0;
            v = this.readWord(0x88);
            ret = this.LINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0x%X)\n', st(1).name, ret, v);
            end
        end
        function ret = getREAD_IIN(this)
            ret = 0.0;
            v = this.readWord(0x89);
            ret = this.LINEAR11_2double(v);
            ret = this.uLINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0x%X)\n', st(1).name, ret, v);
            end
        end
        function ret = getREAD_VOUT(this)
            ret = 0.0;
            v = this.readWord(0x8B);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0x%X)\n', st(1).name, ret, v);
            end
        end
        function ret = getREAD_IOUT(this)
            ret = 0.0;
            v = this.readWord(0x8C);
            ret = this.LINEAR11_2double(v);
            ret = this.uLINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0x%X)\n', st(1).name, ret, v);
            end
        end
 
        function ret = getREAD_TEMPERATURE(this)
            ret = 0.0;
            v = this.readWord(0x8D);
            ret = this.LINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f °C (0x%X)\n', st(1).name, ret, v);
            end
        end
        function ret = setVIN_OV_FAULT_RESPONSE(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            ret = this.writeBytes(0x56, uint8(v));
        end
        function ret = setVIN_OV_FAULT_LIMIT(this, v)
            ov = this.double2LINEAR11(v, -1);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(ov));
            end
            ret = this.writeWord(0x55, ov);
        end
        function ret = getVIN_OV_FAULT_LIMIT(this)
            ret = 0.0;
            v = this.readWord(0x55);
            ret = this.LINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0x%X)\n', st(1).name, ret, v);
            end
        end
        
        function ret = setVIN_UV_WARN_LIMIT(this, v)
            %VIN_UV_FAULT_LIMIT is not supported by Sic450!
            sv = this.double2LINEAR11(v, -1);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x58, sv);
        end
        function ret = setVOUT_OV_FAULT_LIMIT(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x40, sv);
        end
        function ret = getVOUT_OV_FAULT_LIMIT(this)
            ret = 0.0;
            v = this.readWord(0x40);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = getVOUT_UV_FAULT_LIMIT(this)
            ret = 0.0;
            v = this.readWord(0x44);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = setVOUT_OV_WARN_LIMIT(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x42, sv);
        end
        
        function ret = setVOUT_UV_FAULT_LIMIT(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x44, sv);
        end
        function ret = setVOUT_UV_WARN_LIMIT(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x43, sv);
        end
        function ret = setVOUT_MARGIN_LOW(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x26, sv);
        end
        function ret = setVOUT_MARGIN_HIGH(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x25, sv);
        end
        function ret = getVOUT_MARGIN_LOW(this)
            ret = 0.0;
            v = this.readWord(0x26);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = getVOUT_MARGIN_HIGH(this)
            ret = 0.0;
            v = this.readWord(0x25);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = getPOWER_GOOD_ON(this)
            ret = 0.0;
            v = this.readWord(0x5E);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = setPOWER_GOOD_ON(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0b%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x5E, sv);
        end
        
        function ret = getPOWER_GOOD_OFF(this)
            ret = 0.0;
            v = this.readWord(0x5F);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = setPOWER_GOOD_OFF(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0b%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x5F, sv);
        end
        function ret = getVOUT_UV_WARN_LIMIT(this)
            ret = 0.0;
            v = this.readWord(0x43);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = getVOUT_OV_WARN_LIMIT(this)
            ret = 0.0;
            v = this.readWord(0x42);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = setVOUT_COMMAND(this, v)
            sv = this.double2LINEAR16(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f V (0b%s)\n', st(1).name, v, dec2bin(sv));
            end
            ret = this.writeWord(0x21, sv);
        end
        function ret = getVOUT_COMMAND(this)
            ret = 0.0;
            v = this.readWord(0x21);
            ret = this.LINEAR16_2double(v, this.expU16);
            if this.debug
                st = dbstack;
                fprintf('%s = %f VOUT (%s)\n', st(1).name, ret, dec2bin(v));
            end
        end
        function ret = setVOUT_SCALE_LOOP(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            ret = this.writeWord(0x29, v);
        end
        function ret = getVOUT_SCALE_LOOP(this)
            ret = this.readWord(0x29);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = setTON_DELAY(this, v)
            f = this.double2LINEAR11(v, 0);
            if this.debug
                st = dbstack;
                fprintf('%s = %f ms (%s)\n', st(1).name, v, dec2bin(f));
            end
            ret = this.writeWord(0x60, f);
        end
        function ret = setTON_RISE(this, v)
            f = this.double2LINEAR11(v, 0);
            if this.debug
                st = dbstack;
                fprintf('%s = %f ms (%s)\n', st(1).name, v, dec2bin(f));
            end
            ret = this.writeWord(0x61, f);
        end
        function ret = getTON_RISE(this)
            ret = 0.0;
            v = this.readWord(0x61);
            ret = this.LINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f ms (0x%X)\n', st(1).name, ret, v);
            end
        end
        function ret = setTON_MAX_FAULT_LIMIT(this, v)
            f = this.double2LINEAR11(v, 0);
            if this.debug
                st = dbstack;
                fprintf('%s = %f ms (%s)\n', st(1).name, v, dec2bin(f));
            end
            ret = this.writeWord(0x62, f);
        end
        function ret = getTON_MAX_FAULT_LIMIT(this)
            ret = 0.0;
            v = this.readWord(0x62);
            ret = this.LINEAR11_2double(v);
            if this.debug
                st = dbstack;
                fprintf('%s = %f ms (0x%X)\n', st(1).name, ret, v);
            end
        end
        function ret = setFREQUENCY_SWITCH(this, v)
            f = this.double2LINEAR11(v, 0);
            if this.debug
                st = dbstack;
                fprintf('%s = %f kHz (%s)\n', st(1).name, v, dec2bin(f));
            end
            ret = this.writeWord(0x33, f);
        end
        function ret = getFREQUENCY_SWITCH(this)
            ret = 0.0;
            f = this.readWord(0x33);
            ret = this.LINEAR11_2double(f);
            if this.debug
                st = dbstack;
                fprintf('%s = %f kHz (%s)\n', st(1).name, ret, f);
            end
        end
        function ret = setOPERATION(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            ret = this.writeBytes(0x01, v);
        end
        function ret = getOPERATION(this)
            ret = this.readBytes(0x01, 1);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = setVOUT_UV_FAULT_RESPONSE(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            ret = this.writeBytes(0x45, v);
        end
        function ret = getVOUT_UV_FAULT_RESPONSE(this)
            ret = this.readBytes(0x45, 1);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = setON_OFF_CONFIGURATION(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            ret = this.writeBytes(0x02, v);
        end
        function ret = getON_OFF_CONFIGURATION(this)
            ret = this.readBytes(0x02, 1);
            if this.debug 
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, ret, dec2bin(ret));
            end
        end
        function ret = setEEPROM_PASSWORD(this, v)
            if this.debug
                st = dbstack;
                fprintf('%s = 0x%X (0b%s)\n', st(1).name, v, dec2bin(v));
            end
            ret = this.blockWriteBytes(0xDB, v);
        end
        function ret = setSTORE_USER_ALL(this)
            if this.debug
                st = dbstack;
                fprintf('%s\n', st(1).name);
            end
            ret = this.writeBytes(0x15, []);
        end
        
        function ret = ReadVOUT(this)
            ret = 0;
            %TODO
%             ret = this.ReadStatus_CML();
%             v = this.ReadCmd(0x78, 1);
%             fprintf('get STATUS_BYTE = 0x%X (0b%s)\n', v, dec2bin(v));
%             v = this.ReadCmd(0x79, 2);
%             fprintf('get STATUS_WORD = 0x%X (0b%s)\n', v, dec2bin(v));
%             
%             v = this.ReadCmd(0x20, 2);
%             fprintf('get VOUT_COMMAND_RAW = 0x%X (0b%s)\n', v, dec2bin(v));
%             
%             ret = this.LINEAR16_2double(v);
%             if this.debug
%                 fprintf('read VOUT_COMMAND = %f V\n', ret);
%             end
%             
%             v = this.ReadCmd(0x8B, 2);
%             fprintf('get VOUT_RAW = 0x%X (0b%s)\n', v, dec2bin(v));
%             
%             ret = this.LINEAR16_2double(v);
%             if this.debug
%                 fprintf('READ_VOUT = %f V\n', ret);
%             end
        end
        function ret = ReadVIN(this)
            ret = 0;
%             %TODO
%             ret = this.ReadStatus_CML();
%             v = this.ReadCmd(0x78, 1);
%             fprintf('get STATUS_BYTE = 0x%X (0b%s)\n', v, dec2bin(v));
%             v = this.ReadCmd(0x79, 2);
%             fprintf('get STATUS_WORD = 0x%X (0b%s)\n', v, dec2bin(v));
%             
%             v = this.ReadCmd(0x88, 2);
%             fprintf('get READ_VIN RAW = 0x%X (0b%s)\n', v, dec2bin(v));
%             
%             ret = this.LINEAR11_2double(v);
%             if this.debug
%                 fprintf('READ_VOUT = %f V\n', ret);
%             end
        end
        function ret = SwitchPWR(this, v)
            %TODO: Check VIN and status before switching
            if v
                msg = 0b10001000;
            else
                msg = 0b00001000;
            end
            if this.debug
                if v
                    str = 'ON';
                else
                    str = 'OFF';
                end
                fprintf('\nSwitch %s\n', str);
            end
            ret = this.setOPERATION(msg);
        end
        function ret = Init(this)
            ret = 1;
                      
            this.setCLEAR_FAULTS();
            this.getVOUT_MODE();
            
            %this.setWRITE_PROTECT(0b00100000);
            
            %check STATUS_CML
            %ret = this.ReadStatus_CML();
        end
        function ret = double2LINEAR16(this, w, exp)
            %converts a double value to a LINEAR16 uint16 according to the PMBus specification
            ret = uint16(w / 2.0^double(exp));
        end
        function ret = LINEAR16_2double(this, v, exp)
            %converts a 16 bit LINEAR16 as uint16 value (according to PMBus specification) to double
            ret = double(v) * 2.0^double(exp);
        end
        function ret = LINEAR11_2double(this, v)
            %converts a 16 bit LINEAR11 as int16 value (according to PMBus specification) to double
            exp = double(bitshift(typecast(v, 'int16'), -11));
            %make sure sign is kept
            m = int16(bitshift(typecast(v, 'int16'), 5));
            m = double(bitshift(m, -5));
            ret = m * 2.0^exp;
        end
        function ret = uLINEAR11_2double(this, v)
            %converts a 16 bit LINEAR11 as uint16 value (according to PMBus specification) to double
            exp = double(bitshift(typecast(v, 'int16'), -11));
            %make sure sign is kept
            m = uint16(bitshift(typecast(v, 'uint16'), 5));
            m = double(bitshift(m, -5));
            ret = m * 2.0^exp;
        end
        function ret = double2LINEAR11(this, w, exp)
            %converts a double value to a LINEAR11 uint16 according to the PMBus specification
            v = int16(exp);
            m = uint16(w / 2^exp);
            v = bitshift(v, 11);
            v = bitand(typecast(v, 'uint16'), 0b1111100000000000);
            m =  bitand(m, 0b0000011111111111);
            ret = typecast(bitor(v, m), 'uint16');
        end
        function ret = Test(this, mode)
            ret = 0;
            switch mode
                case 0
                    fprintf('Test: Switch Off\n');
%                     this.Init();
%                     %get OPERATION
%                     v = this.ReadCmd(0x01, 1);
%                     if this.debug 
%                         fprintf('get OPERATION = 0x%X (0b%s)\n', v, dec2bin(v));
%                     end
%                     %get ON_OFF_CONFIGURATION
%                     v = this.ReadCmd(0x02, 1);
%                     if this.debug 
%                         fprintf('get ON_OFF_CONFIGURATION = 0x%X (0b%s)\n', v, dec2bin(v));
%                     end
%                     this.ClearFaults();
%                     %this.SetWriteProtect(0);
%                     %check STATUS_CML
%                     v = this.ReadStatus_CML();
                    %switch Off
                    %this.setVOUT_COMMAND(2.0);
                    this.SwitchPWR(0);
                    v = this.getSTATUS_CML();
                    v = this.getSTATUS_WORD();
                    v = this.getSTATUS_VOUT();
                    v = this.getSTATUS_INPUT();
                    pause(1.0);
                    this.SwitchPWR(1);
                    v = this.getSTATUS_CML();
                    v = this.getSTATUS_WORD();
                    v = this.getSTATUS_VOUT();
                    v = this.getSTATUS_INPUT();
                    pause(5.0);
                    this.SwitchPWR(0);
                    v = this.getSTATUS_CML();
                    v = this.getSTATUS_WORD();
                    v = this.getSTATUS_VOUT();
                    v = this.getSTATUS_INPUT();
%                 case 1
%                     fprintf('Test: Read VIN, Read VOU\n');
%                     this.ReadVOUT();
                otherwise
                    fprintf('No valid test\n');
            end
        end    
    end
end

