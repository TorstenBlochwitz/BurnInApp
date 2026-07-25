function UnitTests(mode)
    %instantiate
    %b=BurnInApp();
    
    %Allow pause
    pause('on');
    
    switch mode
        case 0
            fprintf('Scan I2C devices (without activating I2C Multiplexer)\n');
            mbc = MBC_TB('COM');
            [adr, ] = mbc.scanI2CAddr();
            if ~isempty(adr)
                fprintf('0x%X\n', adr);
            else
                fprintf('No devices found at I2C bus!\n');
            end
        case 1
            mbc = MBC_TB('COM');
            fprintf('Scan I2C devices (with activated I2C Multiplexer)\n');
            mbc.writeBytesI2C(0xE0, 0, 0x04);
            [adr, ] = mbc.scanI2CAddr();
            if ~isempty(adr)
                fprintf('0x%X\n', adr);
            else
                fprintf('No devices found at I2C bus!\n');
            end
            mbc.resetI2C();

            mbc.reset();
            mbc.setI2Cfrequency(17);
            [adr, ] = mbc.scanI2CAddr();
            mbc.writeBytesI2C(0xE0, 0, 0x00);
            if ~isempty(adr)
                fprintf('0x%X\n', adr);
            else
                fprintf('No devices found at I2C bus!\n');
            end
        case 2
            fprintf('Let LED D1 blink 5 times\n');
            for k=1:5
                b.board.switchStatusLEDMainBoard(1);
                pause(0.5);
                b.board.switchStatusLEDMainBoard(0);
                pause(0.5);
            end
        case 3
            fprintf('Switch MUX off and do not influence LED');
            b.board.setMUX(-1);
            b.board.switchStatusLEDMainBoard(1);
            b.board.setMUX(-1);
            pause(0.5);
            b.board.switchStatusLEDMainBoard(0);
            b.board.setMUX(-1);
        case 4
            fprintf('Switch MUX channel to VDC1 and VDC2, do not influence LED and vice versa');
            %VDC1
            b.board.switchStatusLEDMainBoard(1);
            b.board.setMUX(121);
            pause(5);
            b.board.switchStatusLEDMainBoard(0);
            pause(5);
            %VDC2
            b.board.switchStatusLEDMainBoard(1);
            b.board.setMUX(125);
            pause(5);
            b.board.switchStatusLEDMainBoard(0);
            pause(5);
            b.board.setMUX(1);
            pause(5);
            b.board.setMUX(-1);
        case 5
            fprintf('Test SiC450: On/Off\n');
            b.board.SiC450(1).Test(0);
        case 6
            fprintf('Test SiC450: Set Defaults\n');
            b.board.setSiC450_Defaults(1);
            
            b.board.setSiC450_Voltage(1, 0.3);
            fprintf('Test SiC450: Ramp Up\n');
            b.board.SiC450(1).SwitchPWR(1);
            
            for v=0.3:0.1:5.0
                %pause(0.5);
                disp(v);
                b.board.setSiC450_Voltage(1, v);
%                 pause(0.5);
%                 b.board.SiC450(1).getSTATUS_CML();
%                 b.board.SiC450(1).getSTATUS_WORD();
%                 b.board.SiC450(1).getSTATUS_VOUT();
%                 b.board.SiC450(1).setCLEAR_FAULTS();
            end
            for v=5.0:-0.1:0.3
                %pause(0.5);
                disp(v);
                b.board.setSiC450_Voltage(1, v);
%                 pause(0.5);
%                 b.board.SiC450(1).getSTATUS_CML();
%                 b.board.SiC450(1).getSTATUS_WORD();
%                 b.board.SiC450(1).getSTATUS_VOUT();
%                 b.board.SiC450(1).setCLEAR_FAULTS();
            end
            b.board.SiC450(1).SwitchPWR(0);
        case 7
            fprintf('Switch all LEDs stepwise on\n');
            for i=0:1:20000
                for k=0:1:63
                    b.mbc.writeBytesI2C(0x08, 0, [k 0 20 0 1 1]);
                end
            end
            %Off
            b.mbc.writeBytesI2C(0x08, 0, [k 0 0 0 1 1]);
        case 8
            fprintf('Set frequency and duty cycle\n');
            b.board.SiC450(1).switchI2CMux(1);
            b.mbc.writeBytesI2C(0x08, 0, [130 10 50]);
            b.board.SiC450(1).switchI2CMux(0);
        case 9
            fprintf('Switch VDC1\n');
            b.board.SiC450(1).switchI2CMux(1);
            b.mbc.writeBytesI2C(0x08, 0, [128 2]);
            b.board.SiC450(1).switchI2CMux(0);
        case 10
            fprintf('Switch VDC2\n');
            b.board.SiC450(1).switchI2CMux(1);
            b.mbc.writeBytesI2C(0x08, 0, [129 2]);
            b.board.SiC450(1).switchI2CMux(0);
        case 11
            fprintf('Switch StatusLED\n');
            b.board.SiC450(1).switchI2CMux(1);
            b.mbc.writeBytesI2C(0x08, 0, [131 2]);
            b.board.SiC450(1).switchI2CMux(0);
        case 12
            fprintf('Read GUID of DC/DC Converter Board\n');
            mbc = MBC_TB();
            fprintf('Switch I2C Multiplexer\n');
            I2Cmulti = I2CMultiplexerPCA9542A(mbc, 0, 0xE0, 0x04, 0x00);
            
%             fprintf('Send Data\n');
%             mbc.writeBytesI2C(0x08, 0, [128 1]);
            
            fprintf('Read UUID\n');
            bytes = mbc.queryBytesI2C(0x08, 0, 148 + 1, 1, 1);
            fprintf('UUID = %d\n', bytes(1));
%             for i=1:1:8
%                 fprintf('%d ', bytes(i));
%             end
            fprintf('\n');
        case 13
            fprintf('Write GUID of DC/DC Converter Board\n');
            mbc = MBC_TB();
            fprintf('Switch I2C Multiplexer\n');
            I2Cmulti = I2CMultiplexerPCA9542A(mbc, 0, 0xE0, 0x04, 0x00);
            
            fprintf('Write UUID\n');
            mbc.writeBytesI2C(0x08, 0, [148 + 1 10]);
            fprintf('\n');
        case 14
            fprintf('Read UUID of MainBoard\n');
            ee = EEPROM_M24C02(b.mbc, 0xA0, 0, 0xE0, 0x04, 0);
            uuid = ee.getUUID();
            
            fprintf('UUID = ');
            %fprintf('%x', uuid(1));
            for i=1:1:16
                fprintf('%x', uuid(i));
            end
            fprintf('\n');
        case 15
            fprintf('Write UUID of MainBoard\n');
            ee = EEPROM_M24C02(b.mbc, 0xA0, 0, 0xE0, 0x04, 0);
            ret = ee.setUUID([1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16]);
        case 16
            t = TempSensor_TMP1075(b.mbc, 0x94, 0, 0xE0, 0x04, 0);
            temp = t.getTemperatureCelsius();
            fprintf('IC13: %f °C\n', temp);
            
            t = TempSensor_TMP1075(b.mbc, 0x98, 0, 0xE0, 0x04, 0);
            temp = t.getTemperatureCelsius();
            fprintf('IC10: %f °C\n', temp);
            
            t = TempSensor_TMP1075(b.mbc, 0x9C, 0, 0xE0, 0x04, 0);
            temp = t.getTemperatureCelsius();
            fprintf('IC11: %f °C\n', temp);
        case 17
            mainBoard = MainBoard(b.mbc, 0, 0xE0, 0x04, 0);
            b.board.setSiC450_Defaults(1);
            b.board.setSiC450_Voltage(1, 1.5);
            b.board.switchVDC(1,1);
            
            mainBoard.setMUX(120);
            
            s = ADC_ADS1115(b.mbc, 0x90, 0, 0xE0, 0x04, 0);
            v = s.getVoltageDiff(ADS1115.CONFIG_MUX_DIFF_0_1, ADS1115.GAIN_TWOTHIRDS_6_144);
            fprintf('V_01 = : %f V\n', v);
            
            b.board.switchVDC(1,0);
            mainBoard.setMUX(-1);
        case 18
            fprintf('Read Software Version of DC/DC Converter Board\n');
            mbc = MBC_TB();
            fprintf('Switch I2C Multiplexer\n');
            I2Cmulti = I2CMultiplexerPCA9542A(mbc, 0, 0xE0, 0x04, 0x00);
            fprintf('Write UUID\n');
            bytes = mbc.queryBytesI2C(0x08, 0, 255, 1, 3);
            fprintf('DC/DC Converter Board Software Version = %d.%d.%d\n', bytes(1), bytes(2), bytes(3));
        case 19
            fprintf('Write GUID of DC/DC Converter Board\n');
            mbc = MBC_TB();
            fprintf('Switch I2C Multiplexer\n');
            I2Cmulti = I2CMultiplexerPCA9542A(mbc, 0, 0xE0, 0x04, 0x00);
        case 20
            mbc = MBC_TB();
            I2Cmulti = I2CMultiplexerPCA9542A(mbc, 0, 0xE0, 0x04, 0x00);
            fprintf('Write and start timer\n');
            mbc.writeBytesI2C(0x08, 0, [128 + 4 2 0]);
        case 21
            mbc = MBC_TB();
            I2Cmulti = I2CMultiplexerPCA9542A(mbc, 0, 0xE0, 0x04, 0x00);
            fprintf('Read timer\n');
            bytes = mbc.queryBytesI2C(0x08, 0, 128 + 4, 1, 2);
            fprintf('Current Timer = %d\n', bytes(2) * 256 + bytes(1));
        otherwise
            fprintf('No valid test\n');
    end
       
end