function c = covariance(log, source)
% Horizontal position covariance that belongs to a path source, as struct(t, varN, varE, covNE,
% sdYaw) in s, m^2 and deg, or [] when the log has none for it. Only EKF3 logs it, and only the
% diagonal: XKV1[i] holds V07 (north) and V08 (east) of core i, so covNE is 0 and the ellipses
% come out aligned with north and east.
%
% sdYaw is approximate: EKF3 keeps attitude as a quaternion and logs only the variances of its
% elements (V00..V03), not their covariances, so the yaw sigma is propagated from V00 and V03
% alone for a level vehicle, yaw = 2*atan2(q3, q0). NaN when the log has no XKQ.

c = [];
if ~startsWith(source, 'XKF1') || ~log.has('XKV1'), return; end
name = strrep(source, 'XKF1', 'XKV1');
if ~any(strcmp(log.instances('XKV1'), name)), return; end
s = log.read(name);
[t, i] = unique(s.t);
c = struct('t', t, 'varN', s.V07(i), 'varE', s.V08(i), 'covNE', zeros(size(t)), ...
    'sdYaw', nan(size(t)));
qname = strrep(source, 'XKF1', 'XKQ');
if log.has('XKQ') && any(strcmp(log.instances('XKQ'), qname))
    q = log.read(qname);
    [tq, j] = unique(q.t);
    q0 = interp1(tq, q.Q1(j), t, 'previous');
    q3 = interp1(tq, q.Q4(j), t, 'previous');
    c.sdYaw = rad2deg(2*sqrt(q0.^2.*s.V03(i) + q3.^2.*s.V00(i)));
end
end
