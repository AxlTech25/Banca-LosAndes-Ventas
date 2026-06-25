-- M7: listas negras internas (bloqueo antes de solicitud)

create table if not exists public.lista_negra (
  id uuid primary key default gen_random_uuid(),
  numero_documento varchar(15) not null unique,
  motivo text not null,
  fuente varchar(40) not null default 'interna',
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_lista_negra_documento_activo
  on public.lista_negra (numero_documento)
  where activo = true;

alter table public.lista_negra enable row level security;

create policy "asesor_lista_negra_select"
  on public.lista_negra for select
  to authenticated
  using (activo = true);

insert into public.lista_negra (numero_documento, motivo, fuente)
values
  ('99999999', 'Cliente reportado por fraude documentario', 'interna'),
  ('88888888', 'Restriccion institucional por incumplimiento grave', 'interna')
on conflict (numero_documento) do nothing;
