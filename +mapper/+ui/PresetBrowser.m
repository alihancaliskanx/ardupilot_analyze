classdef PresetBrowser < mapper.ui.Panel
    % Presets tab, like the Presets list on plot.ardupilot.org, with the presets this log can draw:
    % Native presets are the MAVExplorer graphs, grouped by the part of their name before '/';
    % Custom presets are the ones saved here. Selecting one replaces the plotted series with it.
    % The plotted series can be saved under a name as a custom preset, and a selected custom
    % preset can be deleted.

    properties (Access = private)
        App
        Filter
        Tree
        Info
        Name
        Remove
        Ready = struct('name', {}, 'description', {}, 'items', {}, 'user', {})
    end

    methods
        function obj = PresetBrowser(parent, app)
            obj.App = app;
            g = uigridlayout(parent, [4 1]);
            g.RowHeight = {26, '1x', 70, 26};
            g.Padding = [4 4 4 4];
            obj.Filter = uieditfield(g, 'text', 'Placeholder', 'Filter presets', ...
                'ValueChangingFcn', @(~, e) obj.fill(e.Value));
            obj.Tree = uitree(g, 'SelectionChangedFcn', @(~, e) obj.pick(e.SelectedNodes));
            obj.Info = uilabel(g, 'Text', 'Open a log to see the presets it can draw.', ...
                'WordWrap', 'on', 'VerticalAlignment', 'top');
            save = uigridlayout(g, [1 3]);
            save.ColumnWidth = {'1x', 50, 60};
            save.Padding = [0 0 0 0];
            obj.Name = uieditfield(save, 'text', 'Placeholder', 'Name for the plotted series', ...
                'ValueChangedFcn', @(~, ~) obj.save());
            uibutton(save, 'Text', 'Save', 'ButtonPushedFcn', @(~, ~) obj.save());
            obj.Remove = uibutton(save, 'Text', 'Delete', 'Enable', 'off', ...
                'Tooltip', 'Delete the selected custom preset', 'ButtonPushedFcn', @(~, ~) obj.removePreset());
        end

        function onLoad(obj, app)
            % Reads the presets again each time, so user presets saved meanwhile are listed
            obj.Ready = obj.Ready([]);
            for p = mapper.plot.presets(app.PresetFolder)
                items = mapper.plot.presetSeries(app.Log, p);
                if isempty(items), continue; end
                obj.Ready(end + 1) = struct('name', p.name, 'description', p.description, ...
                    'items', {items}, 'user', p.user);
            end
            obj.Info.Text = sprintf('%d presets can be drawn from this log.', numel(obj.Ready));
            obj.fill(obj.Filter.Value);
        end

        function focusName(obj)
            focus(obj.Name);
        end
    end

    methods (Access = private)
        function fill(obj, text)
            delete(obj.Tree.Children);
            native = uitreenode(obj.Tree, 'Text', 'Native presets', 'NodeData', 0);
            custom = uitreenode(obj.Tree, 'Text', 'Custom presets', 'NodeData', 0);
            groups = containers.Map();
            for k = 1:numel(obj.Ready)
                p = obj.Ready(k);
                if ~isempty(text) && ~contains(p.name, text, 'IgnoreCase', true) ...
                        && ~contains(p.description, text, 'IgnoreCase', true)
                    continue
                end
                if p.user
                    uitreenode(custom, 'Text', p.name, 'NodeData', k);
                    continue
                end
                parts = split(p.name, '/');
                if isscalar(parts), parts = [{'Other'}; parts]; end
                if ~isKey(groups, parts{1})
                    groups(parts{1}) = uitreenode(native, 'Text', parts{1}, 'NodeData', 0);
                end
                uitreenode(groups(parts{1}), 'Text', strjoin(parts(2:end), '/'), 'NodeData', k);
            end
            if isempty(custom.Children)
                uitreenode(custom, 'Text', '(none saved yet)', 'NodeData', 0);
            end
            expand(native);
            expand(custom);
            if ~isempty(text), expand(obj.Tree, 'all'); end
        end

        function pick(obj, node)
            if isempty(node) || node.NodeData == 0
                obj.Remove.Enable = 'off';
                return
            end
            p = obj.Ready(node.NodeData);
            obj.App.setSelection(p.items(:));
            d = p.description;
            if isempty(d), d = strjoin(p.items, '   '); end
            obj.Info.Text = d;
            obj.Remove.Enable = matlab.lang.OnOffSwitchState(p.user);
        end

        function save(obj)
            name = strtrim(obj.Name.Value);
            if isempty(name) || isempty(obj.App.Selection), return; end
            obj.App.saveUserPreset(name);
            obj.Name.Value = '';
            obj.onLoad(obj.App);
        end

        function removePreset(obj)
            node = obj.Tree.SelectedNodes;
            if isempty(node) || node.NodeData == 0, return; end
            p = obj.Ready(node.NodeData);
            if ~p.user, return; end
            delete(fullfile(obj.App.PresetFolder, 'user', [p.name '.json']));
            obj.onLoad(obj.App);
        end
    end
end
