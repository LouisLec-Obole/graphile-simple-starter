--=============================
--=== Authentication        ===
--=============================

-- Postgraphile intègre par défaut un système d'authentification par JSON Web Token (JWT)
-- Le principe est le suivant, une requête au serveur postgraphile faite avec un JWT dans les headers va utiliser les "claims" du JWT dans les settings de connexion à postgres. Exemple: si le token contient l'id de l'utilisateur, celui-ci sera accessible lors de la connection à la base de données sous: pg_catalog.current_setting('jwt.claims.user_id', true)


create type app_public.jwt_token as (
  role text,
  user_id uuid,
  exp bigint
);



create function app_public.register(email citext, firstname text, phone_number text, birthday timestamptz, password text) returns app_public.jwt_token as $$
declare
  v_token app_public.jwt_token;
begin
  insert into app_public.users(email, firstname, phone_number, birthday) values ($1, $2, $3, $4);

  insert into app_private.user_secrets(user_id, password_hash) values ((select usr.id from app_public.users as usr where usr.email = $1), crypt($5, gen_salt('bf', 8)));

  select usr.role, usr.id, extract(epoch from (now() + interval '2 hours'))
  into v_token
  from app_public.users as usr
  where usr.email = $1;

  return v_token;
end;
$$ language plpgsql volatile security definer;
-- grant execute on function app_public.register to capi_anon;

create function app_public.login(email citext, password text) returns app_public.jwt_token as $$
declare
  v_token app_public.jwt_token;
begin
  if exists (
    select 1
    from app_private.user_secrets as secrets
    where secrets.user_id = (select usr.id from app_public.users as usr where usr.email = $1)
    and secrets.password_hash = crypt($2, secrets.password_hash)
  ) then
    select usr.role, usr.id, extract(epoch from (now() + interval '2 hours'))
    into v_token
    from app_public.users as usr
    where usr.email = $1;

    perform graphile_worker.add_job(
      'log_hello',
      json_build_object(
        'name', (select usr.firstname from app_public.users as usr where usr.email = $1),
        'email', ($1)
        )
      );
  else
      raise exception 'Bad credentials' using errcode = 'BDCRD';
  end if;

  return v_token;
end;
$$ language plpgsql volatile security definer;
-- grant execute on function app_public.login to capi_anon;


