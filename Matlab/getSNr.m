function [ret, str] = getSNr(baseSNr, n)
    if n > 0
        n = n - 1;
    end
    %Checks the baseSNR as string
    %Returns the k-th SNr after baseSNr
    ret = 0;
    str = "";
    SNr = convertCharsToStrings(upper(baseSNr));
    if strlength(SNr) ~= 6
        return
    end
    strPrefix = extractBetween(SNr, 1, 2);
    %is prefix between A and Z (upper case)?
    pr1 = uint64(char(extractBetween(strPrefix, 1, 1)));
    pr2 = uint64(char(extractBetween(strPrefix, 2, 2)));
    if pr1 < uint8('A') || pr1 > uint8('Z') || pr2 < uint8('A') || pr2 > uint8('Z') 
        return
    end
    %is postfix a valid number?
    po = uint16(str2num(extractBetween(SNr, 3, 6)));
    if isempty(po) || po == 0
        return
    end
    ret = 1;
    if n == 0
        str = SNr;
        return
    end
    %new postfix
    %TODO: Check with po + n = k * 9999
    if uint64(po + n) == 9999
        %special case to exclude 0000
        npo = 9999;
        o1 = 0;
    else
        npo = mod(uint64(po + n), uint64(9999));
        %overflow?
        o1 = idivide(uint64(po + n), uint64(9999));
    end
    npr2 = uint64('A') + mod(uint64(pr2 + o1 - uint64('A')), uint64(26));
    %overflow?
    o2 = idivide(uint64(pr2 + o1 - uint64('A')), uint64(26));
    npr1 = uint64('A') + mod(uint64(pr1 + o2 - uint64('A')), uint64(26));
    %overflow?
    %should work automatically! Yes, it does: test with getSNr('ZZ9999', 1)
    o3 = idivide(uint64(pr1 + o2 - uint64('A')), uint64(26));

    %put everything together
    str = sprintf("%s%s%04d", char(npr1), char(npr2), npo);
end