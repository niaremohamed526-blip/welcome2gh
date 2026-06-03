-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  WELCOME2GHANA (W2G) — Complete Production Schema for Supabase       ║
-- ║  Run this entire file in: Supabase Dashboard → SQL Editor            ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ─── Extensions ──────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";
create extension if not exists postgis;
create extension if not exists pg_trgm;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  1. ENUMS                                                            ║
-- ╚══════════════════════════════════════════════════════════════════════╝
do $$ begin
  create type user_role as enum ('student','tourist','local','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type place_category as enum (
    'hostel','hotel','restaurant','university','hospital',
    'tourist','mall','mosque','church','cafe','study_spot',
    'event','nightlife','transport','market','other'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type post_category as enum (
    'safety','food','transport','accommodation','events',
    'scam_alert','student_life','general'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type alert_type as enum (
    'unsafe_area','scam','traffic','high_crowd','emergency','weather'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type alert_severity as enum ('low','medium','high','critical');
exception when duplicate_object then null; end $$;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  2. PROFILES (extends auth.users)                                    ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text unique,
  role user_role default 'tourist',
  nationality text,
  preferences jsonb default '{}'::jsonb,
  profile_image text,
  language text default 'en',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_profiles_role on public.profiles(role);

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  3. PLACES                                                           ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.places (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  category place_category not null,
  description text,
  address text,
  district text,
  -- coordinates
  lat double precision not null,
  lng double precision not null,
  geom geography(point, 4326),
  -- scores 0-10
  rating numeric(3,1) default 0 check (rating between 0 and 5),
  review_count integer default 0,
  safety_score numeric(3,1) default 0 check (safety_score between 0 and 10),
  crowd_level numeric(3,1) default 0 check (crowd_level between 0 and 10),
  air_quality numeric(3,1) default 0 check (air_quality between 0 and 10),
  noise_level numeric(3,1) default 0 check (noise_level between 0 and 10),
  -- metadata
  price_level text check (price_level in ('$','$$','$$$','$$$$')),
  image_url text,
  images text[] default array[]::text[],
  tags text[] default array[]::text[],
  opening_hours jsonb,
  contact_phone text,
  contact_email text,
  website text,
  -- flags
  verified boolean default false,
  active boolean default true,
  -- audit
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_places_geom on public.places using gist(geom);
create index if not exists idx_places_category on public.places(category);
create index if not exists idx_places_verified on public.places(verified);
create index if not exists idx_places_name_trgm on public.places using gin (name gin_trgm_ops);
create index if not exists idx_places_tags on public.places using gin(tags);

-- auto-populate geom from lat/lng
create or replace function public.set_place_geom()
returns trigger language plpgsql as $$
begin
  new.geom := st_setsrid(st_makepoint(new.lng, new.lat), 4326)::geography;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_places_geom on public.places;
create trigger trg_places_geom
  before insert or update on public.places
  for each row execute function public.set_place_geom();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  4. REVIEWS                                                          ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.reviews (
  id uuid primary key default uuid_generate_v4(),
  place_id uuid not null references public.places(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rating numeric(2,1) not null check (rating between 1 and 5),
  comment text,
  images text[] default array[]::text[],
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(place_id, user_id)
);

create index if not exists idx_reviews_place on public.reviews(place_id);
create index if not exists idx_reviews_user on public.reviews(user_id);

-- recalc place rating + review_count
create or replace function public.recalc_place_rating()
returns trigger language plpgsql as $$
declare v_place_id uuid;
begin
  v_place_id := coalesce(new.place_id, old.place_id);
  update public.places p set
    rating = coalesce((select round(avg(r.rating)::numeric, 1) from public.reviews r where r.place_id = v_place_id), 0),
    review_count = (select count(*) from public.reviews r where r.place_id = v_place_id)
  where p.id = v_place_id;
  return null;
end $$;

drop trigger if exists trg_reviews_recalc on public.reviews;
create trigger trg_reviews_recalc
  after insert or update or delete on public.reviews
  for each row execute function public.recalc_place_rating();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  5. FAVORITES                                                        ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.favorites (
  user_id uuid not null references public.profiles(id) on delete cascade,
  place_id uuid not null references public.places(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, place_id)
);

create index if not exists idx_favorites_user on public.favorites(user_id);

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  6. COMMUNITY POSTS                                                  ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.posts (
  id uuid primary key default uuid_generate_v4(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  category post_category not null default 'general',
  content text not null,
  image_url text,
  location_lat double precision,
  location_lng double precision,
  likes_count integer default 0,
  comments_count integer default 0,
  active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_posts_author on public.posts(author_id);
create index if not exists idx_posts_category on public.posts(category);
create index if not exists idx_posts_created on public.posts(created_at desc);

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  7. POST LIKES                                                       ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

create or replace function public.adjust_post_likes()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'INSERT') then
    update public.posts set likes_count = likes_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update public.posts set likes_count = greatest(0, likes_count - 1) where id = old.post_id;
  end if;
  return null;
end $$;

drop trigger if exists trg_post_likes on public.post_likes;
create trigger trg_post_likes
  after insert or delete on public.post_likes
  for each row execute function public.adjust_post_likes();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  8. POST COMMENTS                                                    ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.post_comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz default now()
);

create index if not exists idx_post_comments_post on public.post_comments(post_id);

create or replace function public.adjust_post_comments()
returns trigger language plpgsql as $$
begin
  if (tg_op = 'INSERT') then
    update public.posts set comments_count = comments_count + 1 where id = new.post_id;
  elsif (tg_op = 'DELETE') then
    update public.posts set comments_count = greatest(0, comments_count - 1) where id = old.post_id;
  end if;
  return null;
end $$;

drop trigger if exists trg_post_comments on public.post_comments;
create trigger trg_post_comments
  after insert or delete on public.post_comments
  for each row execute function public.adjust_post_comments();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  9. FAIR PRICE REPORTS                                               ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.fair_prices (
  id uuid primary key default uuid_generate_v4(),
  service_type text not null,                          -- taxi, trotro, market_item, restaurant
  item_name text,                                      -- e.g. "Airport to Osu", "Plate of jollof"
  route_from text,
  route_to text,
  amount_ghs numeric(10,2) not null check (amount_ghs > 0),
  notes text,
  reported_by uuid references public.profiles(id) on delete set null,
  verified boolean default false,
  flagged boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_fair_prices_service on public.fair_prices(service_type);
create index if not exists idx_fair_prices_item on public.fair_prices(item_name);

-- aggregate view of fair price averages
create or replace view public.fair_price_averages as
select
  service_type,
  item_name,
  route_from,
  route_to,
  round(avg(amount_ghs)::numeric, 2) as avg_price,
  round(min(amount_ghs)::numeric, 2) as min_price,
  round(max(amount_ghs)::numeric, 2) as max_price,
  count(*) as reports_count
from public.fair_prices
where verified = true or flagged = false
group by service_type, item_name, route_from, route_to;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  10. ALERTS                                                          ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.alerts (
  id uuid primary key default uuid_generate_v4(),
  alert_type alert_type not null,
  severity alert_severity not null default 'medium',
  title text not null,
  description text,
  lat double precision,
  lng double precision,
  geom geography(point, 4326),
  radius_meters integer default 1000,
  active boolean default true,
  expires_at timestamptz,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz default now()
);

create index if not exists idx_alerts_geom on public.alerts using gist(geom);
create index if not exists idx_alerts_active on public.alerts(active, expires_at);

create or replace function public.set_alert_geom()
returns trigger language plpgsql as $$
begin
  if new.lat is not null and new.lng is not null then
    new.geom := st_setsrid(st_makepoint(new.lng, new.lat), 4326)::geography;
  end if;
  return new;
end $$;

drop trigger if exists trg_alerts_geom on public.alerts;
create trigger trg_alerts_geom
  before insert or update on public.alerts
  for each row execute function public.set_alert_geom();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  11. IOT SENSOR DATA                                                 ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.iot_data (
  id bigserial primary key,
  sensor_id text not null,
  place_id uuid references public.places(id) on delete set null,
  lat double precision,
  lng double precision,
  noise_db numeric(5,1),
  air_quality_index numeric(5,1),
  crowd_density numeric(5,1),
  temperature_c numeric(4,1),
  humidity_pct numeric(4,1),
  recorded_at timestamptz default now()
);

create index if not exists idx_iot_sensor on public.iot_data(sensor_id, recorded_at desc);
create index if not exists idx_iot_place on public.iot_data(place_id, recorded_at desc);

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  12. NOTIFICATIONS                                                   ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create table if not exists public.notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text,
  data jsonb,
  read boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_notifications_user on public.notifications(user_id, read, created_at desc);

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  13. AUTH TRIGGER — auto-create profile on signup                    ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1), 'New User'),
    new.email,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'tourist')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  14. RPC FUNCTIONS                                                   ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- nearby_places(lat, lng, radius_meters, category_filter)
create or replace function public.nearby_places(
  user_lat double precision,
  user_lng double precision,
  radius_m integer default 5000,
  category_filter place_category default null
)
returns table (
  id uuid, name text, category place_category, address text,
  lat double precision, lng double precision, distance_m double precision,
  rating numeric, review_count integer, safety_score numeric,
  crowd_level numeric, air_quality numeric, noise_level numeric,
  price_level text, image_url text, verified boolean
) language sql stable as $$
  select
    p.id, p.name, p.category, p.address, p.lat, p.lng,
    st_distance(p.geom, st_setsrid(st_makepoint(user_lng, user_lat), 4326)::geography) as distance_m,
    p.rating, p.review_count, p.safety_score, p.crowd_level,
    p.air_quality, p.noise_level, p.price_level, p.image_url, p.verified
  from public.places p
  where p.active = true
    and (category_filter is null or p.category = category_filter)
    and st_dwithin(p.geom, st_setsrid(st_makepoint(user_lng, user_lat), 4326)::geography, radius_m)
  order by distance_m asc;
$$;

-- nearby_alerts(lat, lng, radius_meters)
create or replace function public.nearby_alerts(
  user_lat double precision,
  user_lng double precision,
  radius_m integer default 5000
)
returns table (
  id uuid, alert_type alert_type, severity alert_severity,
  title text, description text, lat double precision, lng double precision,
  distance_m double precision, created_at timestamptz
) language sql stable as $$
  select
    a.id, a.alert_type, a.severity, a.title, a.description,
    a.lat, a.lng,
    st_distance(a.geom, st_setsrid(st_makepoint(user_lng, user_lat), 4326)::geography) as distance_m,
    a.created_at
  from public.alerts a
  where a.active = true
    and (a.expires_at is null or a.expires_at > now())
    and a.geom is not null
    and st_dwithin(a.geom, st_setsrid(st_makepoint(user_lng, user_lat), 4326)::geography, radius_m)
  order by a.severity desc, distance_m asc;
$$;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  15. ROW LEVEL SECURITY                                              ║
-- ╚══════════════════════════════════════════════════════════════════════╝
alter table public.profiles      enable row level security;
alter table public.places        enable row level security;
alter table public.reviews       enable row level security;
alter table public.favorites     enable row level security;
alter table public.posts         enable row level security;
alter table public.post_likes    enable row level security;
alter table public.post_comments enable row level security;
alter table public.fair_prices   enable row level security;
alter table public.alerts        enable row level security;
alter table public.iot_data      enable row level security;
alter table public.notifications enable row level security;

-- profiles policies
drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_all" on public.profiles for select using (true);
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);

-- places: public read, only authenticated can create, only owner/admin can edit
drop policy if exists "places_select_all" on public.places;
create policy "places_select_all" on public.places for select using (active = true);
drop policy if exists "places_insert_auth" on public.places;
create policy "places_insert_auth" on public.places for insert with check (auth.uid() is not null);
drop policy if exists "places_update_owner_or_admin" on public.places;
create policy "places_update_owner_or_admin" on public.places for update using (
  auth.uid() = created_by or exists(select 1 from public.profiles where id = auth.uid() and role = 'admin')
);

-- reviews
drop policy if exists "reviews_select_all" on public.reviews;
create policy "reviews_select_all" on public.reviews for select using (true);
drop policy if exists "reviews_insert_self" on public.reviews;
create policy "reviews_insert_self" on public.reviews for insert with check (auth.uid() = user_id);
drop policy if exists "reviews_update_own" on public.reviews;
create policy "reviews_update_own" on public.reviews for update using (auth.uid() = user_id);
drop policy if exists "reviews_delete_own" on public.reviews;
create policy "reviews_delete_own" on public.reviews for delete using (auth.uid() = user_id);

-- favorites
drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own" on public.favorites for select using (auth.uid() = user_id);
drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own" on public.favorites for insert with check (auth.uid() = user_id);
drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own" on public.favorites for delete using (auth.uid() = user_id);

-- posts
drop policy if exists "posts_select_all" on public.posts;
create policy "posts_select_all" on public.posts for select using (active = true);
drop policy if exists "posts_insert_self" on public.posts;
create policy "posts_insert_self" on public.posts for insert with check (auth.uid() = author_id);
drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own" on public.posts for update using (auth.uid() = author_id);
drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts for delete using (auth.uid() = author_id);

-- post likes & comments
drop policy if exists "post_likes_select_all" on public.post_likes;
create policy "post_likes_select_all" on public.post_likes for select using (true);
drop policy if exists "post_likes_insert_self" on public.post_likes;
create policy "post_likes_insert_self" on public.post_likes for insert with check (auth.uid() = user_id);
drop policy if exists "post_likes_delete_own" on public.post_likes;
create policy "post_likes_delete_own" on public.post_likes for delete using (auth.uid() = user_id);

drop policy if exists "post_comments_select_all" on public.post_comments;
create policy "post_comments_select_all" on public.post_comments for select using (true);
drop policy if exists "post_comments_insert_self" on public.post_comments;
create policy "post_comments_insert_self" on public.post_comments for insert with check (auth.uid() = user_id);
drop policy if exists "post_comments_delete_own" on public.post_comments;
create policy "post_comments_delete_own" on public.post_comments for delete using (auth.uid() = user_id);

-- fair prices
drop policy if exists "fair_prices_select_all" on public.fair_prices;
create policy "fair_prices_select_all" on public.fair_prices for select using (true);
drop policy if exists "fair_prices_insert_auth" on public.fair_prices;
create policy "fair_prices_insert_auth" on public.fair_prices for insert with check (auth.uid() is not null);

-- alerts
drop policy if exists "alerts_select_all" on public.alerts;
create policy "alerts_select_all" on public.alerts for select using (active = true);
drop policy if exists "alerts_insert_auth" on public.alerts;
create policy "alerts_insert_auth" on public.alerts for insert with check (auth.uid() is not null);

-- iot_data: public read, server-only insert (via service role)
drop policy if exists "iot_data_select_all" on public.iot_data;
create policy "iot_data_select_all" on public.iot_data for select using (true);

-- notifications: only owner can see
drop policy if exists "notifications_select_own" on public.notifications;
create policy "notifications_select_own" on public.notifications for select using (auth.uid() = user_id);
drop policy if exists "notifications_update_own" on public.notifications;
create policy "notifications_update_own" on public.notifications for update using (auth.uid() = user_id);

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  16. REALTIME — enable for live feed + alerts                        ║
-- ╚══════════════════════════════════════════════════════════════════════╝
do $$ begin
  alter publication supabase_realtime add table public.posts;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.post_comments;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.post_likes;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.alerts;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.reviews;
exception when others then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.notifications;
exception when others then null; end $$;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  17. SEED DATA — 6 Accra places matching the app                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝
insert into public.places (
  name, category, description, address, district, lat, lng,
  rating, review_count, safety_score, crowd_level, air_quality, noise_level,
  price_level, verified, image_url, tags
) values
('Kotoka International Airport', 'transport',
  'Main airport of Ghana, modern Terminal 3. Intercontinental and domestic flights.',
  'Airport City, Accra', 'Airport', 5.6052, -0.1668,
  4.2, 312, 9.1, 6.5, 7.0, 7.8, '$$', true,
  'https://images.unsplash.com/photo-1530521954074-e64f6810b32d?w=800',
  array['Transport','Airport','International']),

('Labadi Beach', 'tourist',
  'Most popular beach in Accra. Vibrant atmosphere with music, food and ocean views.',
  'La, Accra', 'La', 5.5545, -0.1288,
  4.5, 890, 7.5, 8.2, 8.5, 7.0, '$', true,
  'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800',
  array['Beach','Tourism','Weekend']),

('University of Ghana', 'university',
  'Premier university of Ghana. Beautiful campus, libraries, sports facilities.',
  'Legon, Accra', 'Legon', 5.6508, -0.1868,
  4.7, 540, 9.5, 6.0, 8.0, 4.5, '$', true,
  'https://images.unsplash.com/photo-1562774053-701939374585?w=800',
  array['University','Education','Student-Friendly']),

('Osu Oxford Street', 'restaurant',
  'The heart of Accra nightlife, dining and shopping. Street food, cafes and restaurants.',
  'Osu, Accra', 'Osu', 5.5560, -0.1769,
  4.3, 1200, 7.0, 9.0, 6.5, 8.5, '$$', true,
  'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
  array['Food','Nightlife','Shopping']),

('Madina Market', 'market',
  'Major trotro and taxi market to the northeast metropolis. Dense activity in the morning.',
  'Madina, Accra', 'Madina', 5.6720, -0.1675,
  3.8, 220, 6.5, 9.5, 5.5, 9.0, '$', true,
  'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800',
  array['Transport','Market','Trotro']),

('Accra Mall', 'mall',
  'Premier shopping mall in Accra. International brands, food court and cinema.',
  'Tetteh Quarshie, Accra', 'Tetteh Quarshie', 5.6360, -0.1701,
  4.4, 670, 9.0, 7.5, 8.2, 6.0, '$$$', true,
  'https://images.unsplash.com/photo-1519566335946-e6f65f0f4fdf?w=800',
  array['Shopping','Mall','Food Court'])
on conflict do nothing;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  18. FAIR PRICE SEED — common Accra rates                            ║
-- ╚══════════════════════════════════════════════════════════════════════╝
insert into public.fair_prices (service_type, item_name, route_from, route_to, amount_ghs, verified) values
('taxi', 'Airport to Osu',     'Kotoka Airport', 'Osu',           90,  true),
('taxi', 'Airport to Legon',   'Kotoka Airport', 'Legon',         120, true),
('taxi', 'Osu to Accra Mall',  'Osu',            'Accra Mall',    40,  true),
('trotro', 'Legon to Madina',  'Legon',          'Madina',        3,   true),
('trotro', 'Circle to Madina', 'Kwame Nkrumah',  'Madina',        5,   true),
('restaurant', 'Plate of jollof', null, null, 25, true),
('restaurant', 'Plate of waakye', null, null, 20, true),
('market_item', 'Bottle of water (small)', null, null, 2, true),
('market_item', 'SIM card', null, null, 10, true)
on conflict do nothing;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  19. ALERTS SEED                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════╝
insert into public.alerts (alert_type, severity, title, description, lat, lng, radius_meters) values
('scam',       'high',   'Pickpockets reported',     'Pickpockets active near Makola Market this afternoon. Stay alert.', 5.5474, -0.2050, 800),
('high_crowd', 'medium', 'Heavy crowd in Osu',       'Osu Oxford Street is currently very crowded for night festivities.', 5.5560, -0.1769, 500),
('traffic',    'medium', 'Heavy traffic on N1',      'Stop-and-go traffic between Kotoka and Tetteh Quarshie.',           5.6200, -0.1700, 1200)
on conflict do nothing;

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ✅ DONE                                                              ║
-- ║  Next: Storage → SQL Editor → Storage tab → create buckets:          ║
-- ║    - 'avatars'   (public)                                            ║
-- ║    - 'places'    (public)                                            ║
-- ║    - 'reviews'   (public)                                            ║
-- ║    - 'posts'     (public)                                            ║
-- ╚══════════════════════════════════════════════════════════════════════╝
