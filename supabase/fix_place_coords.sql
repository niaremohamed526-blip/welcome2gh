-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Welcome2GH — correct place coordinates to real locations             ║
-- ║  Source: OpenStreetMap geocoding (matches Google Maps closely).       ║
-- ║  Run in Supabase → SQL Editor → Run. The places geom trigger          ║
-- ║  recomputes the PostGIS geom automatically on update.                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝

update public.places set lat = 5.646598, lng = -0.188004 where name ilike '%University of Ghana%';
update public.places set lat = 5.622768, lng = -0.174048 where name ilike '%Accra Mall%';
update public.places set lat = 5.563937, lng = -0.140608 where name ilike '%Labadi%';
update public.places set lat = 5.558366, lng = -0.182332 where name ilike '%Osu Oxford%';
update public.places set lat = 5.679268, lng = -0.169481 where name ilike '%Madina Market%';
update public.places set lat = 5.603840, lng = -0.168269 where name ilike '%Kotoka%';
update public.places set lat = 5.548074, lng = -0.206932 where name ilike '%Makola%';
update public.places set lat = 5.669556, lng = -0.189508 where name ilike '%Wisconsin%';

-- Note: "Atlantic Mall" could not be matched in OpenStreetMap (likely a
-- custom/user place). Fix it from the app: Add Place screen → search or tap
-- the map, or edit it in the Admin dashboard.
