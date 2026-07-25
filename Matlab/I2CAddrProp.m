classdef I2CAddrProp < int8
    enumeration
        DO_NOTHING(-1)       %do not communicate with this I2C Adress
        DONT_USE_OFFSET(0)   %do not add the offset value to I2Caddress / 2 and communicate
        USE_OFFSET(1)        %add the offset value to I2Caddress / 2 and communicate
    end
end