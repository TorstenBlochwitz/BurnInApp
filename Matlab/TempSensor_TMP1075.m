classdef TempSensor_TMP1075 < SMBusDev
    %TEMPSENSOR_TMP1075: Support functions for the Temperatur sensor TMP1075

    methods
        function this = TempSensor_TMP1075(MBC, address, offset, MPaddr, cOn, cOff)
            this@SMBusDev(MBC,address, offset, MPaddr, cOn, cOff, 0);
            %Device is by default in continuous conversion mode with a sample rate of 27.5 ms
        end
        
        function temp = getTemperatureCelsius(this)
            temp = -273.5;
            if this.connected
                temp = double(this.readWord(0)) * 0.0625 / 16;
            end
        end
    end
end

