-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Welcome2GH — let admins edit/moderate posts, alerts & fair prices     ║
-- ║  Run in Supabase → SQL Editor → Run. Safe to run more than once.       ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- POSTS: admin (in addition to the author) may update.
drop policy if exists "posts_update_admin" on public.posts;
create policy "posts_update_admin" on public.posts for update
  using (auth.uid() = author_id
         or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ALERTS: admin (or the creator) may update / delete.
alter table public.alerts enable row level security;
drop policy if exists "alerts_update_admin" on public.alerts;
create policy "alerts_update_admin" on public.alerts for update
  using (auth.uid() = created_by
         or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));
drop policy if exists "alerts_delete_admin" on public.alerts;
create policy "alerts_delete_admin" on public.alerts for delete
  using (auth.uid() = created_by
         or exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- FAIR PRICES: admin may update / delete.
alter table public.fair_prices enable row level security;
drop policy if exists "fair_prices_update_admin" on public.fair_prices;
create policy "fair_prices_update_admin" on public.fair_prices for update
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));
drop policy if exists "fair_prices_delete_admin" on public.fair_prices;
create policy "fair_prices_delete_admin" on public.fair_prices for delete
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));
