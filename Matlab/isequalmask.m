function tf = isequalmask(a, b, mask)
    %ISEQUALMASK Compare integers using a bit mask.
    %
    %   tf = ISEQUALMASK(a, b, mask)
    %
    %   Returns true if all bits selected by MASK are equal in A and B.
    %   A, B, and MASK must have the same size and integer class.
    %
    %   Example:
    %       a    = uint8(bin2dec('10101100'));
    %       b    = uint8(bin2dec('11101101'));
    %       mask = uint8(bin2dec('00111100'));
    %
    %       tf = isequalmask(a,b,mask)
    
    % Basic validation
    if ~isequal(size(a), size(b), size(mask))
        error('A, B, and MASK must have the same size.');
    end

    if ~isinteger(a) || ~strcmp(class(a), class(b)) || ~strcmp(class(a), class(mask))
        error('A, B, and MASK must be integer arrays of the same class.');
    end

    % Bits that differ and are selected by the mask
    diffMasked = bitand(bitxor(a, b), mask);

    % Equal if no selected bit differs anywhere
    tf = all(diffMasked(:) == 0);
end
