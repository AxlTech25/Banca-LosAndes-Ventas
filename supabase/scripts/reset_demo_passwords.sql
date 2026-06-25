-- Restablece contraseña demo. Ver fix_auth_sql_users.sql si el login falla por NULL.

create extension if not exists pgcrypto;

update auth.users
set encrypted_password = crypt('Demo2026!', gen_salt('bf'))
where email like '%@losandes.internal'
  and email <> '104592@losandes.internal';
