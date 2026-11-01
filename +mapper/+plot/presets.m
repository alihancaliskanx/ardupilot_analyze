function P = presets(folder)
% Plot presets: the MAVExplorer graphs in folder/*.xml (as used by plot.ardupilot.org) and the
% user's own in folder/user/*.json. Each preset has
%   name          'Group/Title' for the MAVExplorer graphs, the file name for user presets
%   description   text, may be empty
%   alternatives  cell of cellstr; each is one way to draw the graph, for a different kind of log
%   user          true for a preset saved by the user
%
% P = mapper.plot.presets(fullfile(mapperFolder, 'presets'))

P = struct('name', {}, 'description', {}, 'alternatives', {}, 'user', {});
for f = dir(fullfile(folder, '*.xml'))'
    s = readstruct(fullfile(f.folder, f.name));
    for g = s.graph(:)'
        alts = cellfun(@splitItems, cellstr(g.expression(:)), 'UniformOutput', false);
        d = '';
        if isfield(g, 'description') && ~ismissing(g.description), d = strtrim(char(g.description)); end
        P(end + 1) = struct('name', char(g.nameAttribute), 'description', d, ...
            'alternatives', {alts'}, 'user', false); %#ok<AGROW>
    end
end
for f = dir(fullfile(folder, 'user', '*.json'))'
    cfg = jsondecode(fileread(fullfile(f.folder, f.name)));
    sel = cfg.Select;
    if isstruct(sel), items = {sel.expr}; else, items = cellstr(sel)'; end
    [~, name] = fileparts(f.name);
    P(end + 1) = struct('name', name, 'description', '', 'alternatives', {{items}}, ...
        'user', true); %#ok<AGROW>
end
end

function items = splitItems(expr)
% Items are separated by spaces outside parentheses; a ':2' suffix (second axis in MAVExplorer)
% is dropped, since every series here has its own axis
items = {};
depth = 0;
cur = '';
for ch = char(expr)
    if ch == '(', depth = depth + 1; elseif ch == ')', depth = depth - 1; end
    if isspace(ch) && depth == 0
        if ~isempty(cur), items{end + 1} = cur; end %#ok<AGROW>
        cur = '';
    else
        cur(end + 1) = ch; %#ok<AGROW>
    end
end
if ~isempty(cur), items{end + 1} = cur; end
items = regexprep(items, ':\d+$', '');
end
