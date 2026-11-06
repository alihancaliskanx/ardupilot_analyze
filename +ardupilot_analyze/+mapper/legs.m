function L = legs(f, sigmaFix)
% The leg between each pair of consecutive position fixes f (see PathView.fixes), assuming both
% fixes put the vehicle on its true position. The path the EKF integrated from the first fix to
% just before the second is compared with the true displacement between the two:
%   dpsi    track rotation, deg clockwise; a constant heading error rotates the whole leg by it
%   scale   integrated length over true length (DVL scale error)
%   dpsiSd  1-sigma of dpsi from the fix uncertainty sigmaFix (m) at both ends
% Legs shorter than MIN_LENGTH give NaN: the fix uncertainty swamps the angle.

MIN_LENGTH = 2;
L = struct('t0', {}, 't1', {}, 'length', {}, 'dpsi', {}, 'dpsiSd', {}, 'scale', {});
for k = 1:numel(f) - 1
    tru = [f(k + 1).east - f(k).east, f(k + 1).north - f(k).north];
    est = [f(k + 1).eastBefore - f(k).east, f(k + 1).northBefore - f(k).north];
    len = hypot(tru(1), tru(2));
    dpsi = NaN; sd = NaN; scale = NaN;
    if len >= MIN_LENGTH
        dpsi = mod(atan2d(est(1), est(2)) - atan2d(tru(1), tru(2)) + 180, 360) - 180;
        sd = rad2deg(sqrt(2)*sigmaFix/len);
        scale = hypot(est(1), est(2))/len;
    end
    L(end + 1) = struct('t0', f(k).t, 't1', f(k + 1).t, 'length', len, 'dpsi', dpsi, ...
        'dpsiSd', sd, 'scale', scale); %#ok<AGROW>
end
end
