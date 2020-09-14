-- Enter migration here


/*

create role capi_anon;
create role capi_user;
create role capi_admin;

grant capi_anon to capi_user;
grant capi_user to capi_admin;

*/





-- Extensions
-- ==========
--  We require some built-in postgres extensions to manage crytology notably: generating UUIDs, crypting passwords...
create extension if not exists pgcrypto;
create extension if not exists citext;

drop schema if exists app_public cascade;
create schema app_public;
grant usage on schema public, app_public to capi_anon;

drop schema if exists app_private cascade;
create schema app_private;

create type app_public.user_roles as enum ('capi_anon', 'capi_user', 'capi_admin');

-- ================ Helper function pour avoir l'id de l'utilisateur courant à partir de son token
create function app_public.current_user_id() returns uuid as $$
begin
  return nullif(pg_catalog.current_setting('jwt.claims.user_id', true), '')::uuid;
end;
$$ language plpgsql stable security definer set search_path to pg_catalog, public, pg_temp;




-- ===================== Trigger to keep updated_at field true !
create function app_private.tg__timestamps() returns trigger as $$
begin
  NEW.created_at = (case when TG_OP = 'INSERT' then NOW() else OLD.created_at end);
  NEW.updated_at = NOW();
  return NEW;
end;
$$ language plpgsql volatile;
