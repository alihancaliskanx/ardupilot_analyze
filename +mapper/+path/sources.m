function S = sources()
% Messages a horizontal path can be drawn from. They are logged by every ArduPilot vehicle
% (Copter, Plane, Rover, Sub); a new source is one more row here.
% convert takes the struct from DataFlashLog.read and returns a path (see fromNed).

S = struct( ...
    'type',    {'XKF1',          'NKF1',          'POS',           'GPS'}, ...
    'label',   {'EKF3 position', 'EKF2 position', 'AHRS position', 'GPS'}, ...
    'convert', {@ned,            @ned,            @geo,            @geo});
end

function p = ned(s)
p = mapper.path.fromNed(s.t, s.PN, s.PE);
end

function p = geo(s)
p = mapper.path.fromGeo(s.t, s.Lat, s.Lng);
end
