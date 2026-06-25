-- =============================================================================
-- Corrige usuarios Auth creados por SQL que no pueden hacer login
-- Causa: GoTrue falla si email_change u otros campos string son NULL
-- Ejecutar en Banco_DBAndes si solo funciona 104592 (creado en Dashboard)
-- Contraseña resultante (excepto 104592): Demo2026!
-- =============================================================================

create extension if not exists pgcrypto;

update auth.users
set
  email_change = coalesce(email_change, ''),
  email_change_token_new = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  confirmation_token = coalesce(confirmation_token, ''),
  recovery_token = coalesce(recovery_token, ''),
  phone_change = coalesce(phone_change, ''),
  phone_change_token = coalesce(phone_change_token, ''),
  reauthentication_token = coalesce(reauthentication_token, ''),
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  updated_at = now()
where email like '%@losandes.internal'
  and email <> '104592@losandes.internal';

-- Restablece contraseña demo (no toca 104592 manual)
update auth.users
set encrypted_password = crypt('Demo2026!', gen_salt('bf'))
where email like '%@losandes.internal'
  and email <> '104592@losandes.internal';

select email, email_change = '' as auth_ok
from auth.users
where email like '%@losandes.internal'
order by email;
