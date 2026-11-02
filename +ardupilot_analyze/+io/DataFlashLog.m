classdef DataFlashLog < handle
    % ArduPilot DataFlash (.BIN) log of any vehicle. The file is indexed once when opened;
    % a message type is decoded the first time it is read and kept in a cache.
    %
    % log = ardupilot_analyze.io.DataFlashLog('00000027.BIN');
    % s = log.read('XKF1[0]');      % instance 0; s.t is time since boot in seconds

    properties (SetAccess = private)
        File
        Vehicle = 'unknown'     % copter, plane, rover, sub, tracker or unknown
        Firmware = ''
    end

    properties (Access = private)
        Data                    % whole file as uint8
        Fmt                     % FMT definitions indexed by message type id + 1
        Pos                     % offset of every non-FMT message
        Typ                     % its type id
        InstanceField           % type name -> name of its instance field (unit '#' in FMTU)
        Cache
    end

    methods
        function obj = DataFlashLog(file)
            obj.File = file;
            obj.Cache = containers.Map();
            obj.InstanceField = containers.Map();
            obj.index();
            obj.readInstanceFields();
            obj.detectVehicle();
        end

        function names = types(obj)
            % Message types that have at least one message in the log, sorted
            ids = unique(obj.Typ);
            names = {obj.Fmt(double(ids) + 1).name};
            names = sort(names(~cellfun(@isempty, names)));
        end

        function tf = has(obj, type)
            tf = any(strcmp(obj.types(), type));
        end

        function tf = hasInstances(obj, type)
            tf = isKey(obj.InstanceField, type);
        end

        function f = numericFields(obj, type)
            % Plottable fields: numbers only, without the timestamp and the instance field
            fmt = obj.Fmt(obj.typeId(type) + 1);
            f = fmt.cols(~ismember(fmt.format, 'nNZa'));
            skip = {'TimeUS'};
            if isKey(obj.InstanceField, type), skip{end + 1} = obj.InstanceField(type); end
            f = setdiff(f, skip, 'stable');
        end

        function names = instances(obj, type)
            % {'XKF1[0]', 'XKF1[1]', ...} for a type with instances, {type} otherwise
            if ~isKey(obj.InstanceField, type)
                names = {type};
                return
            end
            s = obj.read(type);
            v = unique(s.(obj.InstanceField(type)));
            names = arrayfun(@(k) sprintf('%s[%d]', type, k), v, 'UniformOutput', false)';
        end

        function s = read(obj, name)
            % One message type, or one instance of it as 'TYPE[n]', as a struct of column vectors.
            % Text fields are string arrays; s.t is TimeUS in seconds when the type has it.
            if isKey(obj.Cache, name)
                s = obj.Cache(name);
                return
            end
            tok = regexp(name, '^(\w+)\[(\d+)\]$', 'tokens', 'once');
            if isempty(tok)
                s = obj.decode(name);
            else
                all = obj.read(tok{1});
                if ~isKey(obj.InstanceField, tok{1})
                    error('%s has no instances', tok{1});
                end
                keep = all.(obj.InstanceField(tok{1})) == str2double(tok{2});
                s = structfun(@(v) v(keep, :), all, 'UniformOutput', false);
            end
            obj.Cache(name) = s;
        end

        function span = timeSpan(obj)
            % First and last TimeUS in the log, in seconds
            span = [Inf -Inf];
            for id = unique(obj.Typ)'
                f = obj.Fmt(double(id) + 1);
                if isempty(f.cols) || ~strcmp(f.cols{1}, 'TimeUS') || f.format(1) ~= 'Q', continue; end
                off = obj.Pos(obj.Typ == id);
                t = double([obj.u64(off(1) + 3), obj.u64(off(end) + 3)])/1e6;
                span = [min(span(1), t(1)), max(span(2), t(2))];
            end
        end
    end

    methods (Access = private)
        function index(obj)
            % A message is 0xA3 0x95 <type id> <payload>; its length comes from the FMT message
            % (type 128, 89 bytes) that defines the type, so the file is walked from the start.
            fid = fopen(obj.File, 'r');
            if fid < 0, error('cannot open %s', obj.File); end
            d = fread(fid, Inf, '*uint8');
            fclose(fid);
            n = numel(d);
            cand = find(d(1:end - 2) == 163 & d(2:end - 1) == 149);
            len = zeros(256, 1);
            len(129) = 89;
            fmt = repmat(struct('name', '', 'format', '', 'cols', {{}}, 'len', 0), 256, 1);
            pos = zeros(numel(cand), 1);
            typ = zeros(numel(cand), 1, 'uint8');
            cnt = 0;
            next = 1;
            for k = 1:numel(cand)
                p = cand(k);
                if p < next, continue; end      % header bytes inside the payload of a message
                t = d(p + 2);
                L = len(double(t) + 1);
                if L == 0, continue; end
                if p + L - 1 > n, break; end
                if t == 128
                    mt = double(d(p + 3)) + 1;
                    len(mt) = double(d(p + 4));
                    fmt(mt).name = cstr(d(p + 5:p + 8));
                    fmt(mt).format = cstr(d(p + 9:p + 24));
                    % names that are MATLAB keywords (a column called 'function') become valid
                    % ones here, so the instance field and the decoded struct use the same name
                    fmt(mt).cols = matlab.lang.makeValidName(strsplit(cstr(d(p + 25:p + 88)), ','));
                    fmt(mt).len = len(mt);
                else
                    cnt = cnt + 1;
                    pos(cnt) = p;
                    typ(cnt) = t;
                end
                next = p + L;
            end
            obj.Data = d;
            obj.Fmt = fmt;
            obj.Pos = pos(1:cnt);
            obj.Typ = typ(1:cnt);
        end

        function id = typeId(obj, type)
            id = find(strcmp({obj.Fmt.name}, type), 1) - 1;
            if isempty(id), error('no message type %s in %s', type, obj.File); end
        end

        function s = decode(obj, type)
            id = obj.typeId(type);
            f = obj.Fmt(id + 1);
            off = obj.Pos(obj.Typ == id);
            s = struct();
            B = obj.Data(off + (3:f.len - 1));      % n x payload bytes
            if isvector(B), B = reshape(B, numel(off), []); end
            col = 1;
            for i = 1:numel(f.format)
                [cls, sz, scale] = fieldType(f.format(i));
                bytes = B(:, col:col + sz - 1);
                col = col + sz;
                if strcmp(cls, 'char')
                    v = erase(strtrim(string(char(bytes))), char(0));
                elseif f.format(i) == 'a'           % int16[32], kept as rows
                    v = reshape(typecast(reshape(bytes', [], 1), 'int16'), 32, [])';
                else
                    v = double(typecast(reshape(bytes', [], 1), cls))*scale;
                end
                s.(matlab.lang.makeValidName(f.cols{i})) = v;
            end
            if isfield(s, 'TimeUS'), s.t = s.TimeUS/1e6; end
        end

        function readInstanceFields(obj)
            if ~obj.has('FMTU'), return; end
            u = obj.decode('FMTU');
            for k = 1:numel(u.FmtType)
                f = obj.Fmt(u.FmtType(k) + 1);
                i = find(char(u.UnitIds(k)) == '#', 1);
                if ~isempty(f.name) && ~isempty(i) && i <= numel(f.cols)
                    obj.InstanceField(f.name) = f.cols{i};
                end
            end
        end

        function detectVehicle(obj)
            if ~obj.has('MSG'), return; end
            m = obj.decode('MSG');
            kinds = {'ArduSub', 'sub'; 'ArduRover', 'rover'; 'APM:Rover', 'rover'; ...
                'ArduCopter', 'copter'; 'APM:Copter', 'copter'; 'ArduPlane', 'plane'; ...
                'APM:Plane', 'plane'; 'AntennaTracker', 'tracker'};
            for k = 1:numel(m.Message)
                hit = find(startsWith(m.Message(k), kinds(:, 1)), 1);
                if ~isempty(hit)
                    obj.Firmware = char(m.Message(k));
                    obj.Vehicle = kinds{hit, 2};
                    return
                end
            end
        end

        function v = u64(obj, p)
            v = typecast(obj.Data(p:p + 7), 'uint64');
        end
    end
end

function [cls, sz, scale] = fieldType(c)
scale = 1;
switch c
    case 'b', cls = 'int8';   sz = 1;
    case {'B', 'M'}, cls = 'uint8'; sz = 1;
    case 'h', cls = 'int16';  sz = 2;
    case 'H', cls = 'uint16'; sz = 2;
    case 'i', cls = 'int32';  sz = 4;
    case 'I', cls = 'uint32'; sz = 4;
    case 'f', cls = 'single'; sz = 4;
    case 'd', cls = 'double'; sz = 8;
    case 'q', cls = 'int64';  sz = 8;
    case 'Q', cls = 'uint64'; sz = 8;
    case 'c', cls = 'int16';  sz = 2; scale = 0.01;
    case 'C', cls = 'uint16'; sz = 2; scale = 0.01;
    case 'e', cls = 'int32';  sz = 4; scale = 0.01;
    case 'E', cls = 'uint32'; sz = 4; scale = 0.01;
    case 'L', cls = 'int32';  sz = 4; scale = 1e-7;
    case 'n', cls = 'char';   sz = 4;
    case 'N', cls = 'char';   sz = 16;
    case 'Z', cls = 'char';   sz = 64;
    case 'a', cls = 'int16';  sz = 64;
    otherwise, error('unknown DataFlash format character %s', c);
end
end

function s = cstr(b)
b = b(:)';
z = find(b == 0, 1);
if ~isempty(z), b = b(1:z - 1); end
s = char(b);
end
