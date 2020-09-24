create table app_public.users (
  id uuid not null default gen_random_uuid() primary key,
  email citext unique not null check (email ~ '[^\s][^@\s]+@[^@]+\.[^@]+'),
  firstname text not null,
  phone_number text,
  birthday timestamptz not null check (birthday < now()),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  role app_public.user_roles not null default 'capi_user'
);
-- premier niveau de sécurité
grant select on app_public.users to capi_anon;
grant update (email, firstname, phone_number, birthday) on app_public.users to capi_user;
-- On active les RLS pour sécuriser la table
alter table app_public.users enable row level security;
-- On créé des politiques d'accès aux données
create policy select_all on app_public.users
  for select
  to capi_anon
  using(true);
-- on créé une politique pour que l'utilisateur ne puisse modifier que ses données
create policy update_self on app_public.users
  for update
  to capi_user
  using (id = app_public.current_user_id());
-- Tous les pouvoirs pour l'admin
create policy admin_has_power on app_public.users
  for all
  to capi_admin
  using(true)
  with check(true);


-- comment on table app_public.users is E'@omit create';

-- ============ Trigger sur la table users pour garder updated toujours à la bonne valeur
create trigger _100_timestamps
  before insert or update on app_public.users
  for each row
  execute procedure app_private.tg__timestamps();



create table app_private.user_secrets (
  user_id uuid unique not null primary key references app_public.users,
  password_hash text
);

-- ============ FIXTURES =================

insert into app_public.users(id, email, firstname, birthday) values
('4f1a111f-065f-4920-a408-b65bb5c076d5', 'louis@capi.com', 'Louis', '1900-12-12'),
('3e986d62-6147-433e-a690-c4c5e9536e4d', 'nicolas@capi.com', 'Nicolas', '1950-12-12'),
('a454817b-4467-4986-92a3-28c79810b8b3', 'corentin@capi.com', 'Corentin', '2019-12-12');

insert into app_private.user_secrets(user_id, password_hash) values
('4f1a111f-065f-4920-a408-b65bb5c076d5', crypt('plop', gen_salt('bf', 8))),
('3e986d62-6147-433e-a690-c4c5e9536e4d', crypt('plop', gen_salt('bf', 8))),
('a454817b-4467-4986-92a3-28c79810b8b3', crypt('plop', gen_salt('bf', 8)));

-- ============ /FIXTURES ================
