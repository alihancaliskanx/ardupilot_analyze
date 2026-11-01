function [allowed, alias] = functions()
% Functions a plot expression may call. alias maps names used by the MAVExplorer presets
% (degrees, radians) to the MATLAB function that does the same.

alias = struct('degrees', 'rad2deg', 'radians', 'deg2rad');
allowed = [{'abs', 'sqrt', 'exp', 'log', 'log10', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan', ...
    'atan2', 'hypot', 'deg2rad', 'rad2deg', 'mod', 'rem', 'min', 'max', 'round', 'floor', 'ceil', ...
    'sign', 'pi'}, fieldnames(alias)'];
end
