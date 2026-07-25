classdef BurnInActionEnum < uint8
    enumeration
        DO_NOTHING(0)
        CONNECT_DCDC_CONVERTER(1)
        CONNECT_MAINBOARD(2)
        SELF_TEST(3)
        CHECK_PROFILE(4)
        DO_MEASUREMENT(5)
    end
end
