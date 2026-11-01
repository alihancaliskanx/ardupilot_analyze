function [t, y] = evaluate(log, expr)
% Evaluates a plot expression over a log. Fields are written MSG.FIELD or MSG[i].FIELD and can be
% combined with numbers, + - * / ^ (or ** as in Python) ( ) and the functions in
% mapper.plot.functions, e.g.
%   'ATT.Yaw'   'XKF1[0].PN * 2'   'hypot(XKF1[0].VN, XKF1[0].VE)'   'ATT.DesYaw - ATT.Yaw'
% The time base is that of the first field; the others are interpolated onto it.

[ALLOWED, ALIAS] = mapper.plot.functions();

expr = strtrim(char(expr));
[tokens, starts, ends] = regexp(expr, '([A-Z][A-Z0-9_]*(?:\[\d+\])?)\.([A-Za-z_]\w*)', 'tokens', 'start', 'end');
if isempty(tokens)
    error('no MSG.FIELD in "%s"', expr);
end

% Rebuild the expression with the fields replaced by v{k}, checking the text in between
names = cellfun(@(c) [c{1} '.' c{2}], tokens, 'UniformOutput', false);
[unique_names, ~, idx] = unique(names, 'stable');
code = '';
last = 0;
for k = 1:numel(tokens)
    code = [code checkGap(expr(last + 1:starts(k) - 1), ALLOWED, ALIAS) sprintf('v{%d}', idx(k))]; %#ok<AGROW>
    last = ends(k);
end
code = [code checkGap(expr(last + 1:end), ALLOWED, ALIAS)];

v = cell(1, numel(unique_names));
for k = 1:numel(unique_names)
    tok = tokens{find(idx == k, 1)};
    s = log.read(tok{1});
    if ~isfield(s, tok{2}), error('%s has no field %s', tok{1}, tok{2}); end
    if k == 1
        t = s.t;
        v{k} = double(s.(tok{2}));
    else
        v{k} = interp1(s.t, double(s.(tok{2})), t, 'linear', NaN);
    end
end
y = feval(str2func(['@(v) ' code]), v);
if isscalar(y), y = repmat(y, size(t)); end
y = double(y(:));
end

function gap = checkGap(gap, allowed, alias)
% Text between fields may hold only numbers, operators and allowed function names
words = regexp(regexprep(gap, '\d+\.?\d*([eE][-+]?\d+)?', '0'), '[A-Za-z_]\w*', 'match');
bad = setdiff(words, allowed);
if ~isempty(bad)
    error('"%s" is not allowed in an expression', bad{1});
end
if ~isempty(regexp(gap, '[^\w\s\.\+\-\*/\^\(\),]', 'once'))
    error('unexpected character in "%s"', gap);
end
gap = strrep(gap, '**', '^');          % Python power, as in the MAVExplorer presets
for a = fieldnames(alias)'
    gap = regexprep(gap, ['\<' a{1} '\>'], alias.(a{1}));
end
gap = strrep(strrep(strrep(gap, '*', '.*'), '/', './'), '^', '.^');
gap = strrep(strrep(strrep(gap, '..*', '.*'), '../', './'), '..^', '.^');
end
