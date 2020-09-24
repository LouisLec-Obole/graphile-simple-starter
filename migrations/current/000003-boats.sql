create table app_public.boats (
  id uuid not null default gen_random_uuid() primary key,
  name text,
  constructeur text,
  immatriculation text,
  length float check (length>0),
  user_id uuid not null references app_public.users
);

create index on app_public.boats(user_id);
grant all on app_public.boats to capi_user;





-- ============ FIXTURES =================

insert into app_public.boats( id, name, constructeur, immatriculation, length, user_id) values
('61b5f6f0-12d4-4aa6-8737-0ce81bcc7bb3', 'Bateau de louis', 'Janneau', 'XFGH1', 50, '4f1a111f-065f-4920-a408-b65bb5c076d5'),
('9f5715cf-92ff-48b4-8deb-c177f3ef8441', 'Bateau de louis 2', 'Janneau', 'XFGH145', 52, '4f1a111f-065f-4920-a408-b65bb5c076d5'),
('59dd0085-d48c-47ff-896e-fdf68f2d2829', 'Bateau de Nicolas', 'Janneau', 'XFGH2', 46, '3e986d62-6147-433e-a690-c4c5e9536e4d'),
('b16e3a75-afb3-464f-997d-843ef9bb0773', 'Bateau de Corentin', 'Janneau', 'XFGH3', 46, 'a454817b-4467-4986-92a3-28c79810b8b3');

-- ============ /FIXTURES ================



-- Computed columns
-- ================

-- Ici on fait une computed column qui nous donne la taille du bateau en metres

create function app_public.boats_length_meters(any_boat app_public.boats) returns float as $$
select $1.length/3.28;
$$ language sql stable;


create function app_public.boats_user_is_more_than_10(any_boat app_public.boats) returns boolean as $$
select (usr.birthday < (now() - interval '10 years'))
from app_public.users as usr
where usr.id = $1.user_id;
$$ language sql stable;


create function app_public.boats_is_more_than_x_feet(any_boat app_public.boats, x_feet float) returns boolean as $$
select ($1.length > $2);
$$ language sql stable;


-- Après les computed columns, les custom queries
-- ==============================================

create function app_public.boats_with_old_owners_and_very_long(boat_length float) returns setof app_public.boats as $$
select boats.*
from app_public.boats as boats
inner join app_public.users as usr on usr.id = boats.user_id
where usr.birthday < (now() - interval '10 years')
and boats.length > $1;
$$ language sql stable;





-- ================ Passage au temps réel: on veut notifier à la création d'un bateau

-- Dans un premier temps, on crée une procédure qui va executer la fonction pg_notify, avec le topic qui nous intéresse dans notre subscription et un ensemble de variables qu'on va pouvoir utiliser dans notre resolver GraphQL
create function app_public.tg__boat_created() returns trigger as $$
    begin
      perform pg_notify(
          'graphql:new_boat:' || NEW.user_id,
          json_build_object(
              'event', 'A new boat has been created',
              'subject', NEW.id
          )::text
      );
    return NEW;
end; $$ language plpgsql volatile;

create trigger _500_boat_created
after insert on app_public.boats
for each row
execute procedure app_public.tg__boat_created();

create type app_public.boat_equipment_type as enum ('ECDIS', 'GPS', 'VHF');

-- create table app_public.boat_equipment_type (
--   type text primary key,
--   description text
-- );
-- comment on table app_public.boat_equipment_type is E'@enum';
-- insert into app_public.boat_equipment_type (type, description) values
--   ('ECDIS', 'Computer'),
--   ('GPS', 'Global positionning system'),
--   ('VHF', 'Radio');

create table app_public.boat_equipments (
  boat_id uuid not null references app_public.boats on delete cascade,
  -- type text not null references app_public.boat_equipment_type on delete cascade
  type app_public.boat_equipment_type not null
);
grant all on app_public.boat_equipments to capi_anon;
CREATE INDEX ON "app_public"."boat_equipments"("boat_id");


create function app_public.create_boat(
  boat app_public.boats,
  equipments app_public.boat_equipments[]
) returns app_public.boats as $$
declare
  v_boat app_public.boats;
begin
  insert into app_public.boats(name, constructeur, immatriculation, length, user_id) values (
    $1.name,
    $1.constructeur,
    $1.immatriculation,
    $1.length,
    coalesce(app_public.current_user_id(), $1.user_id)
  ) returning * into v_boat;
  insert into app_public.boat_equipments select (v_boat.id)::uuid, equipment.type from unnest($2) as equipment;
  return v_boat;
end; $$ language plpgsql volatile security definer;
