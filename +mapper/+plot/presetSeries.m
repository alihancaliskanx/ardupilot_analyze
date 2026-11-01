function items = presetSeries(log, preset)
% The first alternative of a preset that this log can draw, as a cell of expressions, or {} when
% none can: every MSG.FIELD must be in the log and every function known to mapper.plot.evaluate.

allowed = mapper.plot.functions();
items = {};
for a = preset.alternatives
    ok = true;
    for e = a{1}
        ok = ok && canDraw(log, e{1}, allowed);
        if ~ok, break; end
    end
    if ok
        items = a{1};
        return
    end
end
end

function ok = canDraw(log, expr, allowed)
calls = regexp(expr, '([A-Za-z_]\w*)\s*\(', 'tokens');
refs = regexp(expr, '[A-Z][A-Z0-9_]*(\[\d+\])?\.[A-Za-z_]\w*', 'match');
ok = ~isempty(refs) && all(ismember(cellfun(@(c) c{1}, calls, 'UniformOutput', false), allowed));
for k = 1:numel(refs)
    if ~ok, return; end
    name = extractBefore(refs{k}, '.');
    type = regexprep(name, '\[\d+\]$', '');
    ok = log.has(type) && any(strcmp(log.numericFields(type), extractAfter(refs{k}, '.')));
    if ok && ~strcmp(name, type)
        ok = log.hasInstances(type) && any(strcmp(log.instances(type), name));
    end
end
end
