classdef App < handle
    % Viewer: message tree, time plot and range timeline in the main window, the path in a window of
    % its own; all tied to one time window.
    %
    % app = mapper.ui.App('00000027.BIN');
    % app.setRange([1278 1564]);
    % app.setSelection({'XKF1[0]', 'PN'; 'XKF1[0]', 'PE'});

    properties (SetAccess = private)
        Log = []
        Span = [0 1]                % first and last time in the log (s since boot)
        Range = [0 1]               % selected time window (s)
        Selection = cell(0, 2)      % rows of {message name, field}
        Figure
        PathView                    % path window, empty or deleted when closed
    end

    properties (Access = private)
        Panels = {}
        Tree
        Plot
        Timeline
        LblFile
        EdStart
        EdEnd
    end

    properties (Constant, Access = private)
        MIN_WIDTH = 0.1             % s, narrowest window
    end

    methods
        function app = App(file)
            app.build();
            if nargin > 0 && ~isempty(file)
                app.open(file);
            end
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
            app.Selection = cell(0, 2);
            [~, name, ext] = fileparts(file);
            app.LblFile.Text = sprintf('%s%s   %s', name, ext, app.Log.Firmware);
            app.Figure.Name = ['mapper - ' name ext];
            app.EdStart.Limits = app.Span;
            app.EdEnd.Limits = app.Span;
            app.notifyPanels(@(p) p.onLoad(app));
            app.showPath();
            app.notifyPanels(@(p) p.onSelection(app));
            app.setRange(app.Span, true);
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
            app.Selection = sel;
            app.notifyPanels(@(p) p.onSelection(app));
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
        function build(app)
            app.Figure = uifigure('Name', 'mapper', 'Position', [60 60 1400 900]);
            if exist('theme', 'file'), theme(app.Figure, 'light'); end
            root = uigridlayout(app.Figure, [2 1]);
            root.RowHeight = {30, '1x'};

            bar = uigridlayout(root, [1 7]);
            bar.ColumnWidth = {80, 100, '1x', 60, 90, 60, 90};
            bar.Padding = [0 0 0 0];
            uibutton(bar, 'Text', 'Open...', 'ButtonPushedFcn', @(~, ~) app.openDialog());
            uibutton(bar, 'Text', 'Path window', 'ButtonPushedFcn', @(~, ~) app.showPath());
            app.LblFile = uilabel(bar, 'Text', 'No log loaded');
            uilabel(bar, 'Text', 'Start (s)', 'HorizontalAlignment', 'right');
            app.EdStart = uieditfield(bar, 'numeric', 'ValueDisplayFormat', '%.1f', ...
                'ValueChangedFcn', @(src, ~) app.setRange([src.Value app.Range(2)]));
            uilabel(bar, 'Text', 'End (s)', 'HorizontalAlignment', 'right');
            app.EdEnd = uieditfield(bar, 'numeric', 'ValueDisplayFormat', '%.1f', ...
                'ValueChangedFcn', @(src, ~) app.setRange([app.Range(1) src.Value]));

            body = uigridlayout(root, [1 2]);
            body.ColumnWidth = {280, '1x'};
            body.Padding = [0 0 0 0];
            app.Tree = mapper.ui.MessageTree(body);
            right = uigridlayout(body, [2 1]);
            right.RowHeight = {'1x', 90};
            right.Padding = [0 0 0 0];
            app.Plot = mapper.ui.TimePlot(right);
            app.Timeline = mapper.ui.RangeTimeline(right);
            app.Panels = {app.Tree, app.Plot, app.Timeline};

            app.Figure.WindowButtonDownFcn = @(~, ~) app.mouseDown();
            app.Figure.WindowButtonMotionFcn = @(~, ~) app.mouseMove();
            app.Figure.WindowButtonUpFcn = @(~, ~) app.mouseUp();
            app.Figure.WindowScrollWheelFcn = @(~, e) app.scroll(e);
            app.Figure.CloseRequestFcn = @(~, ~) app.close();
        end

        % The timeline gets the mouse first, then the time plot
        function mouseDown(app)
            if isempty(app.Log), return; end
            if app.Timeline.mouseDown(app), return; end
            app.Plot.Nav.down(app.Figure);
        end

        function mouseMove(app)
            if isempty(app.Log), return; end
            if app.Plot.Nav.move(), return; end
            if app.Timeline.mouseMove(app), return; end
            t = app.Plot.timeAtPointer();
            if ~isempty(t), app.setCursor(t); end
        end

        function mouseUp(app)
            if isempty(app.Log), return; end
            app.Timeline.mouseUp(app);
            app.Plot.Nav.up();
        end

        function scroll(app, evt)
            if isempty(app.Log), return; end
            app.Plot.Nav.scroll(evt);
        end

        function close(app)
            if ~isempty(app.PathView) && isvalid(app.PathView)
                delete(app.PathView);
            end
            delete(app.Figure);
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
