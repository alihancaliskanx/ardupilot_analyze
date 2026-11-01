classdef App < handle
    % Viewer: message tree, time plot and range timeline in the main window, the path in a window of
    % its own; all tied to one time window.
    %
    % app = mapper.ui.App(mapper.ui.themes('rainynight'));
    % app.open('00000027.BIN');
    % app.setRange([1278 1564]);
    % app.setSelection({'XKF1[0]', 'PN'; 'XKF1[0]', 'PE'});   % or {'XKF1[0].PN'; 'ATT.Yaw * 2'}
    % app.addExpression('hypot(XKF1[0].VN, XKF1[0].VE)');

    properties (SetAccess = private)
        Log = []
        Span = [0 1]                % first and last time in the log (s since boot)
        Range = [0 1]               % selected time window (s)
        Selection = struct('expr', {}, 'color', {}, 'error', {})  % plotted series
        Figure
        PathView                    % path window, empty or deleted when closed
        Theme                       % colours, see mapper.ui.themes
        Debug = false               % print mouse events, see mapper.options
        Plot                        % panels, readable so scripts and tests can drive them
        Timeline
        Presets
        PresetFolder = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'presets')
    end

    properties (Access = private)
        Series                      % expr -> struct(t, y), filled on first use
        Panels = {}
        Tree
        Setup
        TabButtons = gobjects(0)    % uibutton per page of the left column
        Pages = gobjects(0)         % uipanel per page, stacked in one grid cell
        LblFile
        EdStart
        EdEnd
    end

    properties (Constant, Access = private)
        MIN_WIDTH = 0.1             % s, narrowest window
    end

    methods
        function app = App(T)
            if nargin < 1, T = mapper.ui.themes('rainynight'); end
            app.Theme = T;
            app.build();
            mapper.ui.applyTheme(app.Figure, T);
        end

        function openDialog(app)
            [f, p] = uigetfile({'*.BIN;*.bin', 'DataFlash log (*.BIN)'}, 'Select a log');
            figure(app.Figure);
            if isequal(f, 0), return; end
            app.open(fullfile(p, f));
        end

        function open(app, file)
            dlg = uiprogressdlg(app.Figure, 'Title', 'mapper', 'Message', 'Reading log...', ...
                'Indeterminate', 'on');
            cleanup = onCleanup(@() close(dlg));
            app.Log = mapper.io.DataFlashLog(file);
            app.Span = app.Log.timeSpan();
            app.Range = app.Span;
            app.Selection = emptySelection();
            app.Series = containers.Map();
            [~, name, ext] = fileparts(file);
            app.LblFile.Text = sprintf('%s%s   %s', name, ext, app.Log.Firmware);
            app.Figure.Name = ['mapper - ' name ext];
            app.EdStart.Limits = app.Span;
            app.EdEnd.Limits = app.Span;
            app.notifyPanels(@(p) p.onLoad(app));
            app.notifyPanels(@(p) p.onSelection(app));
            app.setRange(app.Span, true);
            app.restyle();
        end

        function apply(app, opts)
            % Applies mapper.options in a fixed order: open, filter, select, range, path source,
            % snapshot, close. Scripted runs and tests go through here; with Close the windows are
            % closed on an error too, so a failed run leaves nothing open.
            app.Debug = opts.Debug;
            if ~isempty(opts.Presets), app.PresetFolder = char(opts.Presets); end
            try
                if ~isempty(opts.File), app.open(opts.File); end
                if ~isempty(opts.Filter), app.Tree.setFilter(opts.Filter); end
                if ~isempty(opts.Select), app.setSelection(opts.Select); end
                if ~isempty(opts.Range), app.setRange(opts.Range); end
                if ~isempty(opts.PathSource)
                    app.showPath();
                    app.PathView.selectSource(opts.PathSource);
                end
                if ~isempty(opts.Snapshot), app.snapshot(opts.Snapshot); end
            catch err
                if opts.Close, app.close(); end
                rethrow(err);
            end
            if opts.Close, app.close(); end
        end

        function snapshot(app, prefix)
            % Writes <prefix>_main.png and, if the path window is open, <prefix>_path.png
            folder = fileparts(prefix);
            if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
            drawnow;
            exportapp(app.Figure, [prefix '_main.png']);
            if ~isempty(app.PathView) && isvalid(app.PathView)
                exportapp(app.PathView.Figure, [prefix '_path.png']);
            end
        end

        function close(app)
            if ~isempty(app.PathView) && isvalid(app.PathView)
                delete(app.PathView);
            end
            delete(app.Figure);
        end

        function setRange(app, r, force)
            if isempty(app.Log), return; end
            r = sort(min(max(r(:)', app.Span(1)), app.Span(2)));
            if r(2) - r(1) < app.MIN_WIDTH
                r(2) = min(r(1) + app.MIN_WIDTH, app.Span(2));
                r(1) = r(2) - app.MIN_WIDTH;
            end
            if nargin < 3 && isequal(r, app.Range), return; end
            app.Range = r;
            app.EdStart.Value = r(1);
            app.EdEnd.Value = r(2);
            app.notifyPanels(@(p) p.onRange(app));
        end

        function setSelection(app, sel)
            % sel: n x 2 cell of {message, field}, a cell of expressions, or a struct array with
            % expr and optionally color (RGB or '#rrggbb')
            if iscell(sel) && size(sel, 2) == 2 && ~all(contains(sel(:), '.'))
                sel = strcat(sel(:, 1), '.', sel(:, 2));
            end
            app.Selection = emptySelection();
            if iscell(sel), sel = struct('expr', sel(:)); end
            for k = 1:numel(sel)
                s = sel(k);
                app.Selection(end + 1) = app.makeSeries(s.expr, field(s, 'color', []));
            end
            app.selectionChanged();
        end

        function changeExpressions(app, add, remove)
            % Removes and adds series in one step; the others keep their axis and colour
            app.Selection = app.Selection(~ismember({app.Selection.expr}, remove));
            for k = 1:numel(add)
                if ~any(strcmp({app.Selection.expr}, add{k}))
                    app.Selection(end + 1) = app.makeSeries(add{k}, []);
                end
            end
            app.selectionChanged();
        end

        function addExpression(app, expr)
            if any(strcmp({app.Selection.expr}, expr)), return; end
            app.Selection(end + 1) = app.makeSeries(expr, []);
            app.selectionChanged();
        end

        function removeExpression(app, which)
            % which: index or expression text
            if ischar(which) || isstring(which), which = find(strcmp({app.Selection.expr}, which)); end
            app.Selection(which) = [];
            app.selectionChanged();
        end

        function updateExpression(app, k, name, value)
            % Changes expr or color of series k
            s = app.Selection(k);
            switch name
                case 'expr', s = app.makeSeries(value, s.color);
                case 'color', s.color = value;
                otherwise, error('mapper: a series has no %s', name);
            end
            app.Selection(k) = s;
            app.selectionChanged();
        end

        function savePreset(app, file)
            % Writes the series as JSON that mapper('Config', file) reads back
            sel = rmfield(app.Selection, 'error');
            for k = 1:numel(sel)
                sel(k).color = sprintf('#%02x%02x%02x', round(255*sel(k).color));
            end
            fid = fopen(file, 'w');
            if fid < 0, error('mapper: cannot write %s', file); end
            fprintf(fid, '%s\n', jsonencode(struct('Select', sel), 'PrettyPrint', true));
            fclose(fid);
        end

        function saveUserPreset(app, name)
            % Saves the series as presets/user/<name>.json, listed under User in the Presets tab
            name = regexprep(strtrim(char(name)), '[^\w\- ]', '_');
            folder = fullfile(app.PresetFolder, 'user');
            if ~isfolder(folder), mkdir(folder); end
            app.savePreset(fullfile(folder, [name '.json']));
        end

        function showPage(app, name)
            % Shows one page of the left column; its tab is drawn in the accent colour
            T = app.Theme;
            for k = 1:numel(app.Pages)
                on = strcmp(app.TabButtons(k).Text, name);
                app.Pages(k).Visible = matlab.lang.OnOffSwitchState(on);
                if on
                    app.TabButtons(k).BackgroundColor = T.accent;
                    app.TabButtons(k).FontColor = T.modeText;
                else
                    app.TabButtons(k).BackgroundColor = T.raised;
                    app.TabButtons(k).FontColor = T.foreground;
                end
            end
        end

        function clearSelection(app)
            app.Selection = emptySelection();
            app.selectionChanged();
        end

        function [t, y] = seriesData(app, k)
            % Data of series k; empty when its expression failed
            t = []; y = [];
            s = app.Selection(k);
            if isempty(s.error) && isKey(app.Series, s.expr)
                d = app.Series(s.expr);
                t = d.t; y = d.y;
            end
        end

        function restyle(app)
            % Re-colours what panels drew since the last call (lines, legends)
            mapper.ui.applyTheme(app.Figure, app.Theme);
            if ~isempty(app.PathView) && isvalid(app.PathView)
                mapper.ui.applyTheme(app.PathView.Figure, app.Theme);
            end
        end

        function setCursor(app, t)
            app.notifyPanels(@(p) p.onCursor(app, t));
        end

        function showPath(app)
            % Opens the path window, or brings it to the front if it is open
            if ~isempty(app.PathView) && isvalid(app.PathView)
                figure(app.PathView.Figure);
                return
            end
            app.PathView = mapper.ui.PathView(app);
            app.Panels{end + 1} = app.PathView;
            if ~isempty(app.Log)
                app.PathView.onLoad(app);
                app.PathView.onRange(app);
            end
        end
    end

    methods (Access = private)
        function s = makeSeries(app, expr, color)
            % Evaluates expr once and keeps its data; an error is kept for the plot setup to show
            expr = strtrim(char(expr));
            err = '';
            if ~isKey(app.Series, expr)
                try
                    [t, y] = mapper.plot.evaluate(app.Log, expr);
                    app.Series(expr) = struct('t', t, 'y', y);
                catch e
                    err = e.message;
                end
            end
            if isempty(color)
                color = app.nextColor();
            elseif ischar(color) || isstring(color)
                color = double(sscanf(char(extractAfter(color, 1)), '%2x', [1 3]))/255;
            end
            s = struct('expr', expr, 'color', color(:)', 'error', err);
        end

        function c = nextColor(app)
            % First palette colour not in use yet, cycling once all are taken
            P = app.Theme.palette;
            used = reshape([app.Selection.color], 3, [])';
            for k = 1:size(P, 1)
                if isempty(used) || ~any(all(abs(used - P(k, :)) < 1e-6, 2))
                    c = P(k, :);
                    return
                end
            end
            c = P(mod(numel(app.Selection), size(P, 1)) + 1, :);
        end

        function selectionChanged(app)
            app.notifyPanels(@(p) p.onSelection(app));
            app.restyle();
        end

        function build(app)
            app.Figure = uifigure('Name', 'mapper', 'Position', [60 60 1400 900]);
            root = uigridlayout(app.Figure, [2 1]);
            root.RowHeight = {30, '1x'};

            % Hyprland draws no title bar, so each window has its own close button
            bar = uigridlayout(root, [1 8]);
            bar.ColumnWidth = {80, 70, '1x', 60, 90, 60, 90, 30};
            bar.Padding = [0 0 0 0];
            uibutton(bar, 'Text', 'Open...', 'ButtonPushedFcn', @(~, ~) app.openDialog());
            uibutton(bar, 'Text', 'Map', 'Tooltip', 'Open the path window', ...
                'ButtonPushedFcn', @(~, ~) app.showPath());
            app.LblFile = uilabel(bar, 'Text', 'No log loaded');
            uilabel(bar, 'Text', 'Start (s)', 'HorizontalAlignment', 'right');
            app.EdStart = uieditfield(bar, 'numeric', 'ValueDisplayFormat', '%.1f', ...
                'ValueChangedFcn', @(src, ~) app.setRange([src.Value app.Range(2)]));
            uilabel(bar, 'Text', 'End (s)', 'HorizontalAlignment', 'right');
            app.EdEnd = uieditfield(bar, 'numeric', 'ValueDisplayFormat', '%.1f', ...
                'ValueChangedFcn', @(src, ~) app.setRange([app.Range(1) src.Value]));
            uibutton(bar, 'Text', char(10005), 'Tooltip', 'Close mapper', ...
                'ButtonPushedFcn', @(~, ~) app.close());

            body = uigridlayout(root, [1 2]);
            body.ColumnWidth = {300, '1x'};
            body.Padding = [0 0 0 0];
            % uitabgroup cannot be coloured to the theme, so the left column has its own tab strip:
            % a button per page, the pages stacked in one cell and only the chosen one visible
            side = uigridlayout(body, [2 1]);
            side.RowHeight = {30, '1x'};
            side.Padding = [0 0 0 0];
            side.RowSpacing = 6;
            strip = uigridlayout(side, [1 2]);
            strip.Padding = [0 0 0 0];
            strip.ColumnSpacing = 2;
            names = {'Presets', 'Plot'};
            for k = 1:2
                app.TabButtons(k) = uibutton(strip, 'Text', names{k}, 'Tag', 'keepcolor', ...
                    'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.showPage(names{k}));
                app.Pages(k) = uipanel(side, 'BorderType', 'none');
                app.Pages(k).Layout.Row = 2;
                app.Pages(k).Layout.Column = 1;
            end
            app.Presets = mapper.ui.PresetBrowser(app.Pages(1), app);
            left = uigridlayout(app.Pages(2), [2 1]);
            left.RowHeight = {230, '1x'};
            left.Padding = [0 0 0 0];
            app.Setup = mapper.ui.PlotSetup(left, app);
            app.Tree = mapper.ui.MessageTree(left);
            right = uigridlayout(body, [2 1]);
            right.RowHeight = {'1x', 90};
            right.Padding = [0 0 0 0];
            app.Plot = mapper.ui.TimePlot(right);
            app.Timeline = mapper.ui.RangeTimeline(right);
            app.Panels = {app.Presets, app.Setup, app.Tree, app.Plot, app.Timeline};
            app.showPage('Plot');

            app.Figure.WindowButtonDownFcn = @(~, ~) app.mouseDown();
            app.Figure.WindowButtonMotionFcn = @(~, ~) app.mouseMove();
            app.Figure.WindowButtonUpFcn = @(~, ~) app.mouseUp();
            app.Figure.WindowScrollWheelFcn = @(~, e) app.scroll(e);
            app.Figure.CloseRequestFcn = @(~, ~) app.close();
        end

        % The timeline gets the mouse first, then the time plot
        function trace(app, event, detail)
            if ~app.Debug, return; end
            over = 'outside';
            if app.Plot.Nav.isOver(), over = 'time plot'; end
            if app.Timeline.isOver(), over = 'timeline'; end
            fprintf('[mapper %s] %-6s %-10s over %s\n', char(datetime('now', 'Format', 'HH:mm:ss.SSS')), ...
                event, detail, over);
        end

        function mouseDown(app)
            app.trace('down', app.Figure.SelectionType);
            if isempty(app.Log), return; end
            if app.Timeline.mouseDown(app), return; end
            app.Plot.down(app.Figure);
        end

        function mouseMove(app)
            if isempty(app.Log), return; end
            if app.Plot.move(), return; end
            if app.Timeline.mouseMove(app), return; end
            shape = app.Plot.pointerShape();
            if ~isempty(shape), app.Figure.Pointer = shape; end
            t = app.Plot.timeAtPointer();
            if ~isempty(t), app.setCursor(t); end
        end

        function mouseUp(app)
            app.trace('up', app.Figure.SelectionType);
            if isempty(app.Log), return; end
            app.Timeline.mouseUp(app);
            app.Plot.up();
        end

        function scroll(app, evt)
            app.trace('scroll', sprintf('%+d', evt.VerticalScrollCount));
            if isempty(app.Log), return; end
            app.Plot.scroll(evt);
        end

        function notifyPanels(app, fn)
            % a closed path window leaves a deleted handle behind
            app.Panels = app.Panels(cellfun(@isvalid, app.Panels));
            for k = 1:numel(app.Panels)
                fn(app.Panels{k});
            end
        end
    end
end

function v = field(s, name, default)
if isfield(s, name) && ~isempty(s.(name)), v = s.(name); else, v = default; end
end

function s = emptySelection()
% Series: expr (text), color (RGB), error (text, empty when it evaluated)
s = struct('expr', {}, 'color', {}, 'error', {});
end
