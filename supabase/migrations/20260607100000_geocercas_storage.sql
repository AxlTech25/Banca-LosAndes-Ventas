-- Geocercas (HU-09) + bucket documentos (RF-54)

create table if not exists public.zonas_trabajo (
  id uuid primary key default gen_random_uuid(),
  agencia_id uuid not null references public.agencias (id),
  nombre varchar(100) not null,
  color varchar(7) not null default '#00C1F9',
  poligono_json jsonb not null,
  activa boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.zonas_asesores (
  zona_id uuid not null references public.zonas_trabajo (id) on delete cascade,
  asesor_id uuid not null references public.asesores_negocio (id) on delete cascade,
  primary key (zona_id, asesor_id)
);

alter table public.zonas_trabajo enable row level security;
alter table public.zonas_asesores enable row level security;

create policy "asesor_zonas_select"
  on public.zonas_trabajo for select
  to authenticated
  using (
    agencia_id = public.current_agencia_id()
    or public.current_asesor_perfil() in ('supervisor', 'administrador')
  );

create policy "asesor_zonas_asesor_select"
  on public.zonas_asesores for select
  to authenticated
  using (
    asesor_id = public.current_asesor_id()
    or exists (
      select 1 from public.asesores_negocio an
      where an.id = zonas_asesores.asesor_id
        and an.agencia_id = public.current_agencia_id()
        and public.current_asesor_perfil() in ('supervisor', 'administrador')
    )
  );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'documentos-solicitudes',
  'documentos-solicitudes',
  false,
  1048576,
  array['image/jpeg', 'image/png']
)
on conflict (id) do nothing;

-- Demo geocerca agencia Lima Centro (rectangulo aproximado)
insert into public.zonas_trabajo (id, agencia_id, nombre, color, poligono_json)
select
  '11111111-1111-4111-a111-111111111111',
  'a1111111-1111-4111-8111-111111111111',
  'Zona Lima Centro',
  '#00C1F9',
  '[
    {"lat": -12.03, "lng": -77.06},
    {"lat": -12.03, "lng": -77.02},
    {"lat": -12.07, "lng": -77.02},
    {"lat": -12.07, "lng": -77.06}
  ]'::jsonb
where exists (select 1 from public.agencias where id = 'a1111111-1111-4111-8111-111111111111')
on conflict (id) do nothing;

insert into public.zonas_asesores (zona_id, asesor_id)
select '11111111-1111-4111-a111-111111111111', 'b2222222-2222-4222-8222-222222222222'
where exists (
  select 1 from public.asesores_negocio
  where id = 'b2222222-2222-4222-8222-222222222222'
)
on conflict do nothing;

create policy "asesor_documentos_storage_select"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'documentos-solicitudes'
    and (storage.foldername(name))[1] in (
      select sc.id::text
      from public.solicitudes_credito sc
      where sc.asesor_id = public.current_asesor_id()
    )
  );

create policy "asesor_documentos_storage_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'documentos-solicitudes'
    and (storage.foldername(name))[1] in (
      select sc.id::text
      from public.solicitudes_credito sc
      where sc.asesor_id = public.current_asesor_id()
    )
  );
