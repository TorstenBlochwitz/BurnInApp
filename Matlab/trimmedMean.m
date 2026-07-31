function nMean = trimmedMean(vec)
%TRIMMEDMEAN Calculate mean value of a vector.
%   If the vector contains more than 3 elements,
%   the minimum and maximum values are excluded
%   from the mean calculation.
    vec = vec(:);  % Convert to column vector

    if numel(vec) > 3
        % Remove one occurrence of minimum and maximum value
        [~, minIdx] = min(vec);
        vec(minIdx) = [];

        [~, maxIdx] = max(vec);
        vec(maxIdx) = [];

    end

    nMean = mean(vec);
end