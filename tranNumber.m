%% 文件作者：郑志宇
%% 函数实现了将字符串转化为对应数字的功能
function num = tranNumber(str)
% TRANNUMBER - Convert a string to a double value with unit recognition.
% Usage:
%   num = tranNumber(str)
% Inputs:
%   str - A string with a number and optional unit. The unit can be one of
%         the following:K, M, MEG, HZ (case insensitive).
% Outputs:
%   num - The double value represented by the input string.
% Example:
%   >> num = tranNumber('10k')
%   num = 10000
%   >> num = tranNumber('100MEG')
%   num = 1.0000e+08

% Convert the input string to lower case for case-insensitive comparison.
str = lower(str);

% Extract the numerical value from the input string.
numStr = regexp(str, '\d+(\.\d+)?(e[+-]?\d+)?', 'match');
if isempty(numStr)
    error('No numerical value found in the input string.');
end
num = str2double(numStr{1});

% Extract the unit from the input string.
unitStr = regexp(str, 'meg|k|n|m|u|g', 'match');
if isempty(unitStr)
    return;
end
unit = unitStr{1};

% Convert the unit to a scaling factor.
switch unit
    case 'g'
        scaleFactor = 1e9;
    case 'meg'
        scaleFactor = 1e6;
    case 'k'
        scaleFactor = 1e3;
    case 'm'
        scaleFactor = 1e-3;
    case 'u'
        scaleFactor = 1e-6;
    case 'n'
        scaleFactor = 1e-9;
    otherwise
        error('Unrecognized unit "%s".', unit);
end

% Apply the scaling factor to the numerical value.
num = num * scaleFactor;
end