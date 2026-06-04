-- ╔══════════════════════════════════════════════════════════════════════╗
-- ║  Welcome2GH — Community upgrade migration                              ║
-- ║  Run this in Supabase → SQL Editor → New query → Run.                 ║
-- ║  Safe to run more than once (idempotent).                             ║
-- ╚══════════════════════════════════════════════════════════════════════╝

-- ── 1. Post media: allow videos ───────────────────────────────────────────
alter table public.posts add column if not exists media_type text not null default 'image';
alter table public.posts add column if not exists video_url text;

-- ── 2. Favourite a post ────────────────────────────────────────────────────
create table if not exists public.post_favorites (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  post_id    uuid not null references public.posts(id)    on delete cascade,
  created_at timestamptz default now(),
  primary key (user_id, post_id)
);
create index if not exists idx_post_favorites_user on public.post_favorites(user_id, created_at desc);

alter table public.post_favorites enable row level security;
drop policy if exists "post_favorites_select_own" on public.post_favorites;
create policy "post_favorites_select_own" on public.post_favorites for select using (auth.uid() = user_id);
drop policy if exists "post_favorites_insert_self" on public.post_favorites;
create policy "post_favorites_insert_self" on public.post_favorites for insert with check (auth.uid() = user_id);
drop policy if exists "post_favorites_delete_own" on public.post_favorites;
create policy "post_favorites_delete_own" on public.post_favorites for delete using (auth.uid() = user_id);

-- ── 3. Report a post ───────────────────────────────────────────────────────
create table if not exists public.post_reports (
  id          uuid primary key default uuid_generate_v4(),
  post_id     uuid not null references public.posts(id)    on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason      text,
  created_at  timestamptz default now()
);
alter table public.post_reports enable row level security;
drop policy if exists "post_reports_insert_self" on public.post_reports;
create policy "post_reports_insert_self" on public.post_reports for insert with check (auth.uid() = reporter_id);
drop policy if exists "post_reports_select_admin" on public.post_reports;
create policy "post_reports_select_admin" on public.post_reports for select
  using (exists (select 1 from public.profiles where id = auth.uid() and role = 'admin'));

-- ── 4. Notify the post author on like / comment ────────────────────────────
-- SECURITY DEFINER so the trigger can insert a notification row for ANOTHER
-- user (the post author), which RLS would otherwise block.
create or replace function public.notify_post_interaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_author  uuid;
  v_actor   uuid := new.user_id;
  v_name    text;
  v_kind    text;
  v_snippet text;
begin
  v_kind := case when tg_table_name = 'post_likes' then 'like' else 'comment' end;

  select author_id, left(coalesce(content, ''), 80)
    into v_author, v_snippet
    from public.posts where id = new.post_id;

  -- no post, or you interacted with your own post → no notification
  if v_author is null or v_author = v_actor then
    return new;
  end if;

  select coalesce(name, 'Someone') into v_name from public.profiles where id = v_actor;

  insert into public.notifications (user_id, title, body, data)
  values (
    v_author,
    v_name || (case when v_kind = 'like' then ' liked your post' else ' commented on your post' end),
    v_snippet,
    jsonb_build_object('type', v_kind, 'post_id', new.post_id, 'actor_id', v_actor)
  );
  return new;
end $$;

drop trigger if exists trg_notify_like on public.post_likes;
create trigger trg_notify_like after insert on public.post_likes
  for each row execute function public.notify_post_interaction();

drop trigger if exists trg_notify_comment on public.post_comments;
create trigger trg_notify_comment after insert on public.post_comments
  for each row execute function public.notify_post_interaction();

-- ── Done. (notifications table is already in the realtime publication.) ─────
