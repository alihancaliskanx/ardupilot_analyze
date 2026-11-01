function app = mapper(varargin)
% Log viewer for ArduPilot DataFlash logs (any vehicle), laid out like plot.ardupilot.org:
% message tree on the left, selected fields against time, a range timeline, and the
% horizontal path of the selected time window in a window of its own.
%
% mapper                                        % empty viewer; open a log with Open...
% mapper('00000028.BIN')
% mapper('File', f, 'Select', {'XKF1[0]', 'PN'}, 'Range', [100 400], 'Snapshot', 'out/run1')
% mapper('Config', 'session.json')              % the same options from a file
%
% See mapper.options for all options.

opts = mapper.options(varargin{:});
app = mapper.ui.App(mapper.ui.themes(opts.Theme));
app.apply(opts);
if nargout == 0, clear app; end
end
