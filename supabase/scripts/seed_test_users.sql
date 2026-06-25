-- =============================================================================
-- Usuarios de prueba — Banco_DBAndes / App Fuerza de Ventas
-- Ejecutar ANTES de seed_demo.sql
-- Contraseña común: Demo2026!
-- =============================================================================

create extension if not exists "pgcrypto";

insert into public.agencias (id, nombre, region, lat, lng, activa)
values (
  'a1111111-1111-4111-8111-111111111111',
  'Agencia Los Andes Lima Centro',
  'Lima',
  -12.046374,
  -77.042793,
  true
)
on conflict (id) do nothing;

-- 104592 Juan Perez     → crear MANUAL en Dashboard (Authentication)
-- 105001 Rosa Vega      → segundo operador (M11)
-- 105002 Luis Morales   → tercer operador (M11)
-- 201001 Pedro Salas    → super_operador
-- 301001 Carmen Rios    → supervisor
-- 901001 Admin Demo     → administrador
--
-- Nota: 104592 puede existir ya en Auth con UUID distinto.
--       Ejecutar link_auth_by_email.sql si el login falla.

do $$
declare
  v_instance_id uuid := '00000000-0000-0000-0000-000000000000';
  v_password text := crypt('Demo2026!', gen_salt('bf'));
  rec record;
begin
  for rec in
    select *
    from (
      values
        ('a1010101-0101-4101-8101-010101010102'::uuid, '105001@losandes.internal'),
        ('a1010101-0101-4101-8101-010101010106'::uuid, '105002@losandes.internal'),
        ('a1010101-0101-4101-8101-010101010103'::uuid, '201001@losandes.internal'),
        ('a1010101-0101-4101-8101-010101010104'::uuid, '301001@losandes.internal'),
        ('a1010101-0101-4101-8101-010101010105'::uuid, '901001@losandes.internal')
    ) as t(user_id, email)
  loop
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change, phone_change_token, reauthentication_token
    )
    values (
      v_instance_id, rec.user_id, 'authenticated', 'authenticated', rec.email,
      v_password, now(),
      '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
      now(), now(),
      '', '', '', '', '', '', '', ''
    )
    on conflict (id) do update set
      encrypted_password = excluded.encrypted_password,
      email_confirmed_at = coalesce(auth.users.email_confirmed_at, now());

    insert into auth.identities (
      id, user_id, identity_data, provider, provider_id,
      last_sign_in_at, created_at, updated_at
    )
    values (
      gen_random_uuid(), rec.user_id,
      jsonb_build_object('sub', rec.user_id::text, 'email', rec.email, 'email_verified', true),
      'email', rec.user_id::text, now(), now(), now()
    )
    on conflict (provider, provider_id) do update set updated_at = now();
  end loop;
end $$;

insert into public.asesores_negocio (
  id, user_id, codigo_empleado, nombres, apellidos, agencia_id, perfil, activo
) values
  (
    'b2222222-2222-4222-8222-222222222222',
    coalesce(
      (select id from auth.users where email = '104592@losandes.internal' limit 1),
      '00000000-0000-0000-0000-000000000001'::uuid
    ),
    '104592', 'Juan', 'Perez',
    'a1111111-1111-4111-8111-111111111111', 'operador', true
  ),
  (
    'b3333333-3333-4333-8333-333333333333',
    'a1010101-0101-4101-8101-010101010102',
    '105001', 'Rosa', 'Vega',
    'a1111111-1111-4111-8111-111111111111', 'operador', true
  ),
  (
    'b8888888-8888-4888-8888-888888888801',
    'a1010101-0101-4101-8101-010101010106',
    '105002', 'Luis', 'Morales',
    'a1111111-1111-4111-8111-111111111111', 'operador', true
  ),
  (
    'b4444444-4444-4444-8444-444444444444',
    'a1010101-0101-4101-8101-010101010103',
    '201001', 'Pedro', 'Salas',
    'a1111111-1111-4111-8111-111111111111', 'super_operador', true
  ),
  (
    'b5555555-5555-4555-8555-555555555555',
    'a1010101-0101-4101-8101-010101010104',
    '301001', 'Carmen', 'Rios',
    'a1111111-1111-4111-8111-111111111111', 'supervisor', true
  ),
  (
    'b6666666-6666-4666-8666-666666666666',
    'a1010101-0101-4101-8101-010101010105',
    '901001', 'Admin', 'Demo',
    'a1111111-1111-4111-8111-111111111111', 'administrador', true
  )
on conflict (id) do update set
  user_id = excluded.user_id,
  codigo_empleado = excluded.codigo_empleado,
  nombres = excluded.nombres,
  apellidos = excluded.apellidos,
  perfil = excluded.perfil,
  activo = true;

-- Vincula Auth existente (p. ej. 104592 creado manualmente)
update public.asesores_negocio an
set user_id = u.id
from auth.users u
where u.email = an.codigo_empleado || '@losandes.internal'
  and an.user_id is distinct from u.id;

select codigo_empleado, nombres, perfil, activo
from public.asesores_negocio
order by codigo_empleado;
