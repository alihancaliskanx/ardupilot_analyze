function opts = options(varargin)
% Viewer options from name-value arguments and, optionally, a JSON file. A single argument that is
% not an option name is taken as the log file. Arguments override the file.
%
% opts = ardupilot_analyze.options('00000028.BIN')
% opts = ardupilot_analyze.options('Config', 'session.json', 'Range', [100 200])
%
% Options:
%   File        log to open
%   Filter      text for the message filter
%   Select      series to plot: n x 2 cell {'XKF1[0]', 'PN'; ...}, a cell of expressions
%               {'XKF1[0].PN'; 'ATT.Yaw * 2'}, or a struct array with expr and color
%               (JSON: [["XKF1[0]", "PN"]], ["ATT.Yaw"] or [{"expr": "ATT.Yaw", "color": "#f38ba8"}])
%   Range       time window [start end] in s since boot
%   PathSource  message for the path window, e.g. 'XKF1[1]' or 'GPS'
%   Snapshot    file prefix; writes <prefix>_main.png and <prefix>_path.png after the others are applied
%   Close       true closes the viewer at the end (for scripted runs)
%   Theme       colour set, 'rainynight' (default) or 'light'; see ardupilot_analyze.ui.themes
%   Presets     folder of preset files (*.xml, user/*.json); default: presets next to ardupilot_analyze.m
%   Debug       true prints every mouse event the main window receives; also on when the
%               environment variable ARDUPILOT_ANALYZE_DEBUG is 1
%   Config      JSON file with any of the options above

names = {'File', 'Filter', 'Select', 'Range', 'PathSource', 'Snapshot', 'Close', 'Theme', 'Debug', ...
    'Presets', 'Config'};
opts = cell2struct(cell(numel(names), 1), names, 1);
opts.Close = false;
opts.Debug = strcmp(getenv('ARDUPILOT_ANALYZE_DEBUG'), '1');
opts.Theme = 'rainynight';

if isscalar(varargin) && ~any(strcmpi(varargin{1}, names))
    varargin = [{'File'}, varargin];
end
if mod(numel(varargin), 2)
    error('ardupilot_analyze: options come in name-value pairs');
end

given = struct();
for k = 1:2:numel(varargin)
    name = names(strcmpi(varargin{k}, names));
    if isempty(name), error('ardupilot_analyze: unknown option %s', string(varargin{k})); end
    given.(name{1}) = varargin{k + 1};
end

if isfield(given, 'Config')
    cfg = jsondecode(fileread(given.Config));
    for f = fieldnames(cfg)'
        name = names(strcmpi(f{1}, names));
        if isempty(name), error('ardupilot_analyze: unknown option %s in %s', f{1}, given.Config); end
        opts.(name{1}) = cfg.(f{1});
    end
end
for f = fieldnames(given)'
    opts.(f{1}) = given.(f{1});
end

% jsondecode turns [["A","B"],["C","D"]] into a column of 2 x 1 cells and ["A","B"] into a column
if ~isempty(opts.Select) && ~isstruct(opts.Select)
    if isstring(opts.Select), opts.Select = cellstr(opts.Select); end
    if all(cellfun(@iscell, opts.Select(:)))
        rows = cellfun(@(c) c(:)', opts.Select(:), 'UniformOutput', false);
        opts.Select = vertcat(rows{:});
    end
    exprs = all(contains(opts.Select(:), '.'));
    if exprs
        opts.Select = opts.Select(:);
    elseif numel(opts.Select) == 2
        opts.Select = reshape(opts.Select, 1, 2);
    elseif size(opts.Select, 2) ~= 2
        error('ardupilot_analyze: Select needs pairs of message and field, or expressions');
    end
end
if ~isempty(opts.Range), opts.Range = double(opts.Range(:)'); end
opts.Close = logical(opts.Close);
opts.Debug = logical(opts.Debug);
end
