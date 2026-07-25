function isValid = checkIPAddress(ipAddress)
    % from Copilot
    % Regular expression for a valid IPv4 address
    pattern = '^(\d{1,3}\.){3}\d{1,3}$';
    
    % Check if the input matches the pattern
    if ~isempty(regexp(ipAddress, pattern, 'once'))
        % Split the IP address into its components
        parts = strsplit(ipAddress, '.');
        
        % Check if each part is within the range 0-255
        isValid = all(cellfun(@(x) str2double(x) >= 0 && str2double(x) <= 255, parts));
    else
        isValid = false;
    end
end

