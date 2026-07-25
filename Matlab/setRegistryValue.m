% Set a registry value
% e.g. [status, msg] = setRegistryValue('HKEY_CURRENT_USER', 'Software\MyProgram', 'DataFolder', 'C:\Data')
%      [status, msg] = setRegistryValue('HKEY_CURRENT_USER\Software\MyProgram', 'DataFolder', 'C:\Data')
function [status, msg] = setRegistryValue(rootKey, registryPath, key, value)
    % This function is only available on Windows platforms (no registry on Mac/Linux!)
    if ~ispc
        error('YMA:setRegistryValue:NotWindows','%s only works within Windows',mfilename)
    end
    % Parse the input args
    if nargin < 4
        value = key;
        key = registryPath;
        registryPath = rootKey;
    else
        registryPath = [rootKey '\' registryPath];
    end
    % Prepare the system command
    command = ['reg add ' registryPath ' /f /v ' key];
    if isnumeric(value)  % convert numeric value into a char string
        % Note: only scalar integer values can use /d !
        valueStr = num2str(value);
        if isequal(value, fix(value)) && isscalar(value)
            command = [command ' /t REG_DWORD /d ' valueStr];
        else
            % The ".." are only needed for non-scalar values
            command = [command ' /t REG_SZ /d "' valueStr '"'];
        end
    else  % convert input value into a char string
        command = [command ' /t REG_SZ /d "' char(value) '"'];
    end
    % Execute the system command to update the registry (trap errors)
    [status, msg] = system(command);
    if status
        error('YMA:setRegistryValue:OpFailed',msg)
    end
end  % setRegistryValue