function t = positionFixes(log)
% Times (s) at which a position fix was applied to the EKF: the AURA_POSITION_FIX mission command
% reports "Position fix: <lat> <lon>" when the EKF accepts it and "Position fix: REJECTED ..." or
% "... skipped" when it does not, so only the first form counts. The coordinates in the text are
% rounded, so where the fix put the vehicle is read from the path instead.

t = zeros(0, 1);
if ~log.has('MSG'), return; end
m = log.read('MSG');
ok = ~cellfun(@isempty, regexp(cellstr(m.Message), '^Position fix: -?[\d.]+ -?[\d.]+$', 'once'));
t = m.t(ok);
end
