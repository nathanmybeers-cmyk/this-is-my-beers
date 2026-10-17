-- This is My Beers : classement général des bars (Supabase / PostgreSQL)
-- À exécuter une fois dans Supabase > SQL Editor.

create table if not exists public.bars (
  player_id   text primary key,                        -- identifiant généré par le jeu sur chaque appareil
  pseudo      text not null check (char_length(pseudo) between 1 and 16),
  city        text not null check (char_length(city) between 1 and 40),
  total_ca    integer not null default 0 check (total_ca between 0 and 100000000), -- CA cumulé (€)
  best_night  integer not null default 0 check (best_night between 0 and 1000000),
  day         integer not null default 1,
  size_level  smallint not null default 1,
  staff_count smallint not null default 0,
  updated_at  timestamptz not null default now()
);

create index if not exists bars_total_ca_idx on public.bars (total_ca desc);

alter table public.bars enable row level security;

-- Tout le monde peut lire le classement
create policy "classement lisible par tous" on public.bars
  for select using (true);

-- Le jeu crée et met à jour la ligne de son bar (upsert sur player_id)
create policy "le jeu peut créer son bar" on public.bars
  for insert with check (true);
create policy "le jeu peut mettre à jour son bar" on public.bars
  for update using (true) with check (true);

-- ---------------------------------------------------------------
-- Mode Arcade : une ligne par partie (le classement prend les meilleurs scores)
create table if not exists public.arcade_scores (
  id          bigint generated always as identity primary key,
  player_id   text not null,                              -- identifiant de l'appareil
  pseudo      text not null check (char_length(pseudo) between 1 and 16),
  score       integer not null check (score between 0 and 10000000),
  ca          integer not null default 0 check (ca between 0 and 100000),
  created_at  timestamptz not null default now()
);
create index if not exists arcade_scores_score_idx on public.arcade_scores (score desc);
alter table public.arcade_scores enable row level security;
create policy "scores arcade lisibles par tous" on public.arcade_scores for select using (true);
create policy "le jeu peut enregistrer une partie" on public.arcade_scores for insert with check (true);
