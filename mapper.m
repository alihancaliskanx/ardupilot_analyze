function app = mapper(file)
% Log viewer for ArduPilot DataFlash logs (any vehicle), laid out like plot.ardupilot.org:
% message tree on the left, selected fields against time, a range timeline, and the
% horizontal path of the selected time window below.
%
% mapper                          % pick the log in a dialog
% app = mapper('00000027.BIN');

if nargin < 1, file = []; end
app = mapper.ui.App(file);
if isempty(file), app.openDialog(); end
end
