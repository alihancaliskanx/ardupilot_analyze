function app = ardupilot_analyze(varargin)
% Log viewer for ArduPilot DataFlash logs (any vehicle), laid out like plot.ardupilot.org:
% message tree on the left, selected fields against time, a range timeline, and the
% horizontal path of the selected time window in a window of its own.
%
% ardupilot_analyze                             % empty viewer; open a log with Open...
% ardupilot_analyze('00000028.BIN')
% ardupilot_analyze('File', f, 'Select', {'XKF1[0]', 'PN'}, 'Range', [100 400], 'Snapshot', 'out/run1')
% ardupilot_analyze('Config', 'session.json')   % the same options from a file
%
% See ardupilot_analyze.options for all options.

opts = ardupilot_analyze.options(varargin{:});
app = ardupilot_analyze.ui.App(ardupilot_analyze.ui.themes(opts.Theme));
app.apply(opts);
if nargout == 0, clear app; end
end
