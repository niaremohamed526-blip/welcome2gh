-- ════════════════════════════════════════════════════════════════════════
--  Add new place categories to the `place_category` enum.
--  Run this in the Supabase SQL Editor.  Safe to re-run (IF NOT EXISTS).
--
--  NOTE: `ALTER TYPE ... ADD VALUE` cannot run inside a transaction block on
--  some Postgres versions. If the editor wraps statements in a transaction and
--  errors, run these lines one at a time.
-- ════════════════════════════════════════════════════════════════════════

alter type place_category add value if not exists 'beach';
alter type place_category add value if not exists 'museum';
alter type place_category add value if not exists 'park';
alter type place_category add value if not exists 'bar';
alter type place_category add value if not exists 'pharmacy';
alter type place_category add value if not exists 'bank';
alter type place_category add value if not exists 'supermarket';
alter type place_category add value if not exists 'gym';
alter type place_category add value if not exists 'salon';
alter type place_category add value if not exists 'gas_station';
alter type place_category add value if not exists 'library';
