classdef MessageTree < mapper.ui.Panel
    % Message types of the log as a checkbox tree: type -> instance -> field. Checked fields are
    % the selection the time plot draws. Children are built when a node is first opened, since a
    % log has a few hundred types and thousands of fields.

    properties (Access = private)
        App
        Filter
        Tree
    end

    methods
        function obj = MessageTree(parent)
            g = uigridlayout(parent, [2 1]);
            g.RowHeight = {26, '1x'};
            g.Padding = [0 0 0 0];
            obj.Filter = uieditfield(g, 'text', 'Placeholder', 'Filter messages', ...
                'ValueChangingFcn', @(~, e) obj.fill(e.Value));
            obj.Tree = uitree(g, 'checkbox', ...
                'NodeExpandedFcn', @(~, e) obj.populate(e.Node), ...
                'CheckedNodesChangedFcn', @(~, ~) obj.checked());
        end

        function onLoad(obj, app)
            obj.App = app;
            obj.Filter.Value = '';
            obj.fill('');
        end
    end

    methods (Access = private)
        function fill(obj, text)
            % Lists the types whose name or one of whose fields contains text. A type found by its
            % fields shows only those fields, opened, unless that needs decoding its instances.
            delete(obj.Tree.Children);
            log = obj.App.Log;
            for type = log.types()
                fields = log.numericFields(type{1});
                if isempty(text) || contains(type{1}, text, 'IgnoreCase', true)
                    obj.addBranch(obj.Tree, type{1}, 'type', fields);
                    continue
                end
                hit = fields(contains(fields, text, 'IgnoreCase', true));
                if isempty(hit), continue; end
                n = obj.addBranch(obj.Tree, type{1}, 'type', hit);
                n.Text = sprintf('%s  (%s)', type{1}, strjoin(hit, ', '));
                if ~log.hasInstances(type{1})
                    obj.populate(n);
                    expand(n);
                end
            end
        end

        function n = addBranch(~, parent, name, kind, fields)
            n = uitreenode(parent, 'Text', name, 'NodeData', nodeData(kind, name, '', fields));
            uitreenode(n, 'Text', '...', 'NodeData', nodeData('stub', '', '', {}));
        end

        function populate(obj, node)
            d = node.NodeData;
            if d.done, return; end
            delete(node.Children);
            log = obj.App.Log;
            inst = {d.name};
            if strcmp(d.kind, 'type'), inst = log.instances(d.name); end
            if numel(inst) > 1 || ~strcmp(inst{1}, d.name)
                for k = 1:numel(inst)
                    obj.addBranch(node, inst{k}, 'instance', d.fields);
                end
            else
                for f = d.fields
                    uitreenode(node, 'Text', f{1}, 'NodeData', nodeData('field', d.name, f{1}, {}));
                end
            end
            d.done = true;
            node.NodeData = d;
        end

        function checked(obj)
            % A checked type or instance that was never opened gets its children built and checked
            nodes = obj.Tree.CheckedNodes;
            added = {};
            for k = 1:numel(nodes)
                d = nodes(k).NodeData;
                if ~strcmp(d.kind, 'field') && ~strcmp(d.kind, 'stub') && ~d.done
                    obj.populate(nodes(k));
                    added{end + 1} = nodes(k).Children; %#ok<AGROW>
                end
            end
            if ~isempty(added)
                obj.Tree.CheckedNodes = unique([nodes; vertcat(added{:})]);
                nodes = obj.Tree.CheckedNodes;
            end
            sel = cell(0, 2);
            for k = 1:numel(nodes)
                d = nodes(k).NodeData;
                if strcmp(d.kind, 'field')
                    sel(end + 1, :) = {d.name, d.field}; %#ok<AGROW>
                end
            end
            obj.App.setSelection(sel);
        end
    end
end

function d = nodeData(kind, name, field, fields)
% Every node carries the same fields so the tree callbacks can read any node alike
d = struct('kind', kind, 'name', name, 'field', field, 'fields', {fields}, ...
    'done', any(strcmp(kind, {'field', 'stub'})));
end
