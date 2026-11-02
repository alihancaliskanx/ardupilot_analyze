function c = covariance(log, source)
% Horizontal position covariance that belongs to a path source, as struct(t, varN, varE, covNE)
% in s and m^2, or [] when the log has none for it. Only EKF3 logs it, and only the diagonal:
% XKV1[i] holds V07 (north) and V08 (east) of core i, so covNE is 0 and the ellipses come out
% aligned with north and east.

c = [];
if ~startsWith(source, 'XKF1') || ~log.has('XKV1'), return; end
name = strrep(source, 'XKF1', 'XKV1');
if ~any(strcmp(log.instances('XKV1'), name)), return; end
s = log.read(name);
[t, i] = unique(s.t);
c = struct('t', t, 'varN', s.V07(i), 'varE', s.V08(i), 'covNE', zeros(size(t)));
end
