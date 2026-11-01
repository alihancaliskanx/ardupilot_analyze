classdef PlotSetup < mapper.ui.Panel
    % The plotted series, like "Plots Setup" on plot.ardupilot.org: one row per series with its
    % expression (editable), colour (palette or any colour) and a remove button, and
    % below them a field to add an expression and a clear. Saving them as a preset is in the
    % Presets tab. The rows scroll.

    properties (Access = private)
        App
        Rows
        NewExpr
    end

    methods
        function obj = PlotSetup(parent, app)
            obj.App = app;
            p = uipanel(parent, 'Title', 'Plots setup', 'BorderType', 'none');
            g = uigridlayout(p, [3 1]);
            g.RowHeight = {'1x', 26, 26};
            g.Padding = [0 0 0 0];
            g.RowSpacing = 4;
            obj.Rows = uigridlayout(g, [1 1], 'Scrollable', 'on');
            add = uigridlayout(g, [1 2]);
            add.ColumnWidth = {'1x', 30};
            add.Padding = [0 0 0 0];
            obj.NewExpr = uieditfield(add, 'text', 'Placeholder', 'Add expression, e.g. ATT.DesYaw - ATT.Yaw', ...
                'ValueChangedFcn', @(~, ~) obj.add());
            uibutton(add, 'Text', '+', 'ButtonPushedFcn', @(~, ~) obj.add());
            uibutton(g, 'Text', 'Clear', 'ButtonPushedFcn', @(~, ~) obj.clear());
            obj.render();
        end

        function onLoad(obj, ~)
            obj.render();
        end

        function onSelection(obj, ~)
            obj.render();
        end
    end

    methods (Access = private)
        function render(obj)
            delete(obj.Rows.Children);
            sel = obj.App.Selection;
            if isempty(sel)
                obj.Rows.RowHeight = {'fit'};
                obj.Rows.ColumnWidth = {'1x'};
                uilabel(obj.Rows, 'Text', 'Plot something first: tick a field below or add an expression.', ...
                    'WordWrap', 'on');
                return
            end
            heights = {};
            obj.Rows.ColumnWidth = {'1x', 36, 24};
            r = 0;
            for k = 1:numel(sel)
                s = sel(k);
                r = r + 1;
                heights{end + 1} = 24; %#ok<AGROW>
                place(uieditfield(obj.Rows, 'text', 'Value', s.expr, ...
                    'ValueChangedFcn', @(src, ~) obj.App.updateExpression(k, 'expr', src.Value)), r, 1);
                place(uicolorpicker(obj.Rows, 'Value', s.color, 'Tooltip', 'Colour', ...
                    'ValueChangedFcn', @(src, ~) obj.App.updateExpression(k, 'color', src.Value)), r, 2);
                place(uibutton(obj.Rows, 'Text', 'x', 'Tooltip', 'Remove', ...
                    'ButtonPushedFcn', @(~, ~) obj.App.removeExpression(k)), r, 3);
                if ~isempty(s.error)
                    r = r + 1;
                    heights{end + 1} = 'fit'; %#ok<AGROW>
                    place(uilabel(obj.Rows, 'Text', ['! ' s.error], 'WordWrap', 'on', 'Tag', 'keepcolor', ...
                        'FontColor', obj.App.Theme.cursor), r, [1 3]);
                end
            end
            obj.Rows.RowHeight = heights;
        end

        function add(obj)
            expr = strtrim(obj.NewExpr.Value);
            if isempty(expr) || isempty(obj.App.Log), return; end
            obj.NewExpr.Value = '';
            obj.App.addExpression(expr);
        end

        function clear(obj)
            obj.App.clearSelection();
        end
    end
end

function place(h, row, col)
h.Layout.Row = row;
h.Layout.Column = col;
end
