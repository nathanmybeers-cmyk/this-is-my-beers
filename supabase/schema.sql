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

-- ---------------------------------------------------------------
-- Comptes « pseudo + mot de passe de partie » : la sauvegarde suit le joueur sur tous ses appareils.
-- La table n'est accessible qu'au travers des fonctions ci-dessous (aucune politique RLS = aucun accès direct).
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.accounts (
  pseudo_key  text primary key,                    -- pseudo en minuscules, sans espaces autour
  pseudo      text not null,
  pass_hash   text not null,                       -- bcrypt
  data        jsonb not null default '{}'::jsonb,  -- { save, arcade, savedAt }
  fails       smallint not null default 0,
  last_fail   timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
alter table public.accounts enable row level security;
revoke all on public.accounts from anon, authenticated;

-- Vérifie un pseudo + mot de passe : { status: 'new' | 'ok' | 'bad' | 'locked', data? }
create or replace function public.account_login(p_pseudo text, p_pass text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare a public.accounts;
begin
  select * into a from public.accounts where pseudo_key = lower(btrim(p_pseudo));
  if not found then return jsonb_build_object('status', 'new'); end if;
  if a.fails >= 5 and a.last_fail > now() - interval '2 minutes' then return jsonb_build_object('status', 'locked'); end if;
  if a.pass_hash <> crypt(p_pass, a.pass_hash) then
    update public.accounts set fails = least(fails + 1, 100), last_fail = now() where pseudo_key = a.pseudo_key;
    return jsonb_build_object('status', 'bad');
  end if;
  if a.fails > 0 then update public.accounts set fails = 0 where pseudo_key = a.pseudo_key; end if;
  return jsonb_build_object('status', 'ok', 'pseudo', a.pseudo, 'data', a.data);
end $$;

-- Crée le compte (refuse si le pseudo est déjà pris) : { status: 'ok' | 'taken' | 'invalid' }
create or replace function public.account_create(p_pseudo text, p_pass text, p_data jsonb)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
begin
  if char_length(btrim(p_pseudo)) not between 1 and 16 or char_length(p_pass) not between 4 and 64
     or octet_length(coalesce(p_data, '{}'::jsonb)::text) > 400000 then
    return jsonb_build_object('status', 'invalid');
  end if;
  insert into public.accounts (pseudo_key, pseudo, pass_hash, data)
  values (lower(btrim(p_pseudo)), btrim(p_pseudo), crypt(p_pass, gen_salt('bf', 8)), coalesce(p_data, '{}'::jsonb));
  return jsonb_build_object('status', 'ok');
exception when unique_violation then
  return jsonb_build_object('status', 'taken');
end $$;

-- Enregistre la sauvegarde si le mot de passe est bon : true / false
create or replace function public.account_save(p_pseudo text, p_pass text, p_data jsonb)
returns boolean language plpgsql security definer set search_path = public, extensions as $$
declare a public.accounts;
begin
  if octet_length(p_data::text) > 400000 then return false; end if;
  select * into a from public.accounts where pseudo_key = lower(btrim(p_pseudo));
  if not found or a.pass_hash <> crypt(p_pass, a.pass_hash) then return false; end if;
  update public.accounts set data = p_data, updated_at = now() where pseudo_key = a.pseudo_key;
  return true;
end $$;

revoke all on function public.account_login(text, text), public.account_create(text, text, jsonb), public.account_save(text, text, jsonb) from public;
grant execute on function public.account_login(text, text), public.account_create(text, text, jsonb), public.account_save(text, text, jsonb) to anon, authenticated;
