-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  W2G — ADMIN POLICIES & FUNCTIONS                                    ║
-- ║  Run this AFTER schema.sql                                           ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ─── Helper: is_admin() ──────────────────────────────────────────────────
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- ─── Admin update/delete policies on every table ─────────────────────────

-- profiles: admins can update anyone, delete anyone
drop policy if exists "profiles_admin_update" on public.profiles;
create policy "profiles_admin_update" on public.profiles for update
  using (public.is_admin());

drop policy if exists "profiles_admin_delete" on public.profiles;
create policy "profiles_admin_delete" on public.profiles for delete
  using (public.is_admin());

-- places: admins can verify, update, delete
drop policy if exists "places_admin_all" on public.places;
create policy "places_admin_all" on public.places for all
  using (public.is_admin()) with check (public.is_admin());

-- reviews: admins delete spam
drop policy if exists "reviews_admin_delete" on public.reviews;
create policy "reviews_admin_delete" on public.reviews for delete
  using (public.is_admin());

drop policy if exists "reviews_admin_update" on public.reviews;
create policy "reviews_admin_update" on public.reviews for update
  using (public.is_admin());

-- posts: admins can delete + update
drop policy if exists "posts_admin_delete" on public.posts;
create policy "posts_admin_delete" on public.posts for delete
  using (public.is_admin());

drop policy if exists "posts_admin_update" on public.posts;
create policy "posts_admin_update" on public.posts for update
  using (public.is_admin());

-- post_comments: admins can delete moderation
drop policy if exists "post_comments_admin_delete" on public.post_comments;
create policy "post_comments_admin_delete" on public.post_comments for delete
  using (public.is_admin());

-- alerts: admins create + manage + delete
drop policy if exists "alerts_admin_all" on public.alerts;
create policy "alerts_admin_all" on public.alerts for all
  using (public.is_admin()) with check (public.is_admin());

-- fair_prices: admins verify, flag, delete
drop policy if exists "fair_prices_admin_all" on public.fair_prices;
create policy "fair_prices_admin_all" on public.fair_prices for all
  using (public.is_admin()) with check (public.is_admin());

-- iot_data: admins can insert + delete
drop policy if exists "iot_data_admin_all" on public.iot_data;
create policy "iot_data_admin_all" on public.iot_data for all
  using (public.is_admin()) with check (public.is_admin());

-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  ADMIN STATS — aggregate view                                        ║
-- ╚══════════════════════════════════════════════════════════════════════╝
create or replace view public.admin_stats as
select
  (select count(*) from public.profiles)              as total_users,
  (select count(*) from public.profiles where role = 'admin') as total_admins,
  (select count(*) from public.profiles where role = 'student') as total_students,
  (select count(*) from public.profiles where role = 'tourist') as total_tourists,
  (select count(*) from public.places where active = true)  as total_places,
  (select count(*) from public.places where verified = false and active = true) as unverified_places,
  (select count(*) from public.reviews)               as total_reviews,
  (select count(*) from public.posts where active = true)   as total_posts,
  (select count(*) from public.alerts where active = true)  as active_alerts,
  (select count(*) from public.fair_prices)           as total_prices,
  (select count(*) from public.fair_prices where verified = false) as unverified_prices;
