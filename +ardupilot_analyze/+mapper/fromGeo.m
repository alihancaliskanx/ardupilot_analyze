function p = fromGeo(t, lat, lng)
% Path from latitude and longitude in degrees, in metres from the first valid sample.
% Samples at 0, 0 are logged before a fix and are dropped.

R = 6378137;
ok = lat ~= 0 | lng ~= 0;
t = t(ok); lat = lat(ok); lng = lng(ok);
if isempty(t)
    p = ardupilot_analyze.mapper.fromNed([], [], []);
    return
end
lat0 = deg2rad(lat(1));
p = ardupilot_analyze.mapper.fromNed(t, R*(deg2rad(lat) - lat0), R*cos(lat0)*(deg2rad(lng) - deg2rad(lng(1))));
end
