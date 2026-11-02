function applyTheme(root, T)
% Colours every component under root (a uifigure or any container) with theme T.
% Call it again after drawing, since new axes children and legends start with default colours.

if isa(root, 'matlab.ui.Figure')
    if exist('theme', 'file'), theme(root, T.mode); end
    root.Color = T.background;
end
for h = findall(root)'
    if strcmp(get(h, 'Tag'), 'keepcolor'), continue; end   % error text keeps its colour
    switch h.Type
        case 'uipanel'
            h.BackgroundColor = T.background;
            h.ForegroundColor = T.foreground;
        case 'uigridlayout'
            h.BackgroundColor = T.background;
        case 'uilabel'
            h.FontColor = T.foreground;
        case {'uibutton', 'uidropdown'}
            h.BackgroundColor = T.raised;
            h.FontColor = T.foreground;
        case {'uieditfield', 'uinumericeditfield', 'uicheckboxtree', 'uitree'}
            h.BackgroundColor = T.panel;
            h.FontColor = T.foreground;
        case 'axes'
            h.Color = T.panel;
            h.XColor = T.foreground;
            set(h.YAxis, 'Color', T.foreground);       % both sides when yyaxis is in use
            h.GridColor = T.grid;
            h.GridAlpha = 0.6;
            h.ColorOrder = T.series;
            h.Title.Color = T.foreground;
            if ~isempty(h.Legend)
                h.Legend.TextColor = T.foreground;
                h.Legend.Color = T.background;
                h.Legend.EdgeColor = T.grid;
            end
    end
end
end
