-- App Fuerza de Ventas — esquema según guía HU_AppFuerzaVentas v3 (2026-05-26)
-- Ejecutar en Supabase SQL Editor o con: supabase db push

-- Extensiones útiles
create extension if not exists "pgcrypto";

-- =============================================================================
-- GRUPO IDENTIDAD
-- =============================================================================

create table if not exists public.agencias (
  id uuid primary key default gen_random_uuid(),
  nombre varchar(100) not null,
  region varchar(50),
  lat decimal(10, 7),
  lng decimal(10, 7),
  activa boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.asesores_negocio (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  codigo_empleado varchar(10) not null unique,
  nombres varchar(100) not null,
  apellidos varchar(100) not null,
  agencia_id uuid not null references public.agencias (id),
  perfil varchar(20) not null default 'operador'
    check (perfil in ('operador', 'super_operador', 'supervisor', 'administrador')),
  token_fcm text,
  activo boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists idx_asesores_negocio_agencia on public.asesores_negocio (agencia_id);
create index if not exists idx_asesores_negocio_user on public.asesores_negocio (user_id);

-- =============================================================================
-- GRUPO CLIENTES Y CRÉDITOS
-- =============================================================================

create table if not exists public.clientes (
  id uuid primary key default gen_random_uuid(),
  numero_documento varchar(15) not null unique,
  tipo_documento varchar(5) not null default 'DNI',
  nombres varchar(100) not null,
  apellidos varchar(100) not null,
  fecha_nacimiento date,
  estado_civil varchar(15),
  telefono varchar(15),
  email varchar(100),
  direccion text,
  tipo_negocio varchar(30),
  nombre_negocio varchar(100),
  antiguedad_negocio_meses integer default 0,
  ingresos_estimados decimal(12, 2),
  lat decimal(10, 7),
  lng decimal(10, 7),
  calificacion_sbs varchar(15),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.creditos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clientes (id),
  asesor_id uuid not null references public.asesores_negocio (id),
  agencia_id uuid not null references public.agencias (id),
  producto varchar(30),
  monto_desembolsado decimal(12, 2),
  plazo_meses integer,
  tea decimal(5, 2),
  estado varchar(20) not null default 'vigente',
  fecha_desembolso date,
  fecha_vencimiento date,
  saldo_actual decimal(12, 2),
  cuotas_total integer,
  cuotas_pagadas integer default 0,
  dias_mora integer default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_creditos_cliente on public.creditos (cliente_id);
create index if not exists idx_creditos_asesor on public.creditos (asesor_id);

create table if not exists public.creditos_preaprobados (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.clientes (id),
  asesor_id uuid not null references public.asesores_negocio (id),
  monto_maximo decimal(12, 2) not null,
  plazo_sugerido_meses integer,
  tea_referencial decimal(5, 2),
  score_confianza integer check (score_confianza between 0 and 100),
  vigente boolean not null default true,
  fecha_calculo date,
  fecha_vencimiento date,
  created_at timestamptz not null default now()
);

create table if not exists public.campanas_activas (
  id uuid primary key default gen_random_uuid(),
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  tipo_campana varchar(30) not null,
  monto_ofertado decimal(12, 2),
  activa boolean not null default true,
  fecha_vencimiento date,
  created_at timestamptz not null default now()
);

-- =============================================================================
-- GRUPO OPERACIÓN EN CAMPO
-- =============================================================================

create table if not exists public.cartera_diaria (
  id uuid primary key default gen_random_uuid(),
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  agencia_id uuid not null references public.agencias (id),
  credito_id uuid references public.creditos (id),
  fecha_asignacion date not null default current_date,
  tipo_gestion varchar(30) not null,
  prioridad varchar(10) not null default 'normal',
  score_prioridad integer not null default 0 check (score_prioridad between 0 and 100),
  estado_visita varchar(20) not null default 'pendiente',
  resultado_visita varchar(30),
  observacion_visita text,
  timestamp_visita timestamptz,
  lat_visita decimal(10, 7),
  lng_visita decimal(10, 7),
  orden_manual integer,
  unique (asesor_id, cliente_id, fecha_asignacion)
);

create index if not exists idx_cartera_diaria_asesor_fecha
  on public.cartera_diaria (asesor_id, fecha_asignacion desc, score_prioridad desc);

create table if not exists public.cartera_vencida (
  id uuid primary key default gen_random_uuid(),
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  credito_id uuid not null references public.creditos (id),
  dias_mora integer not null default 0,
  monto_vencido decimal(12, 2) not null default 0,
  fecha_ultimo_contacto date,
  created_at timestamptz not null default now()
);

create table if not exists public.solicitudes_credito (
  id uuid primary key default gen_random_uuid(),
  numero_expediente varchar(20) unique,
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  agencia_id uuid not null references public.agencias (id),
  tipo_negocio varchar(30),
  nombre_negocio varchar(100),
  actividad_economica varchar(10),
  antiguedad_negocio_meses integer,
  ingresos_estimados decimal(12, 2),
  gastos_mensuales decimal(12, 2),
  patrimonio_estimado decimal(12, 2),
  tiene_conyuge boolean default false,
  conyuge_json jsonb,
  tiene_garante boolean default false,
  garante_json jsonb,
  monto_solicitado decimal(12, 2),
  plazo_meses integer,
  moneda varchar(3) default 'PEN',
  tipo_cuota varchar(10) default 'mensual',
  garantia varchar(20),
  destino_credito text,
  cuota_estimada decimal(10, 2),
  tea_referencial decimal(5, 2),
  estado varchar(30) not null default 'borrador',
  monto_aprobado decimal(12, 2),
  motivo_rechazo text,
  condicion_adicional text,
  analista_asignado varchar(100),
  firma_cliente_base64 text,
  lat_captura decimal(10, 7),
  lng_captura decimal(10, 7),
  pendiente_sync boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_solicitudes_asesor_created
  on public.solicitudes_credito (asesor_id, created_at desc);

create table if not exists public.solicitudes_documentos (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes_credito (id) on delete cascade,
  tipo_documento varchar(40) not null,
  storage_url text,
  tamanio_kb integer,
  nitidez_score decimal(5, 2),
  created_at timestamptz not null default now()
);

create table if not exists public.consultas_buro (
  id uuid primary key default gen_random_uuid(),
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  dni_consultado varchar(15) not null,
  calificacion_sbs varchar(20),
  entidades_con_deuda integer,
  deuda_total_pen decimal(12, 2),
  mayor_deuda decimal(12, 2),
  dias_mayor_mora integer,
  resultado_json jsonb,
  firma_consentimiento_base64 text,
  solicitud_id uuid references public.solicitudes_credito (id),
  created_at timestamptz not null default now()
);

create table if not exists public.acciones_cobranza (
  id uuid primary key default gen_random_uuid(),
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  credito_id uuid not null references public.creditos (id),
  tipo_gestion varchar(20) not null,
  resultado varchar(30) not null,
  monto_pagado decimal(12, 2),
  fecha_compromiso date,
  monto_compromiso decimal(12, 2),
  observaciones text,
  lat decimal(10, 7),
  lng decimal(10, 7),
  timestamp_gestion timestamptz not null default now()
);

create table if not exists public.alertas_cartera (
  id uuid primary key default gen_random_uuid(),
  asesor_id uuid not null references public.asesores_negocio (id),
  cliente_id uuid not null references public.clientes (id),
  tipo_alerta varchar(30) not null,
  mensaje text not null,
  leida boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.solicitudes_notas_internas (
  id uuid primary key default gen_random_uuid(),
  solicitud_id uuid not null references public.solicitudes_credito (id) on delete cascade,
  asesor_id uuid not null references public.asesores_negocio (id),
  contenido text not null check (char_length(contenido) <= 500),
  created_at timestamptz not null default now()
);

-- =============================================================================
-- HELPERS RLS
-- =============================================================================

create or replace function public.current_asesor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id
  from public.asesores_negocio
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_agencia_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select agencia_id
  from public.asesores_negocio
  where user_id = auth.uid()
  limit 1;
$$;

create or replace function public.current_asesor_perfil()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select perfil
  from public.asesores_negocio
  where user_id = auth.uid()
  limit 1;
$$;

-- =============================================================================
-- RLS (políticas base según guía)
-- =============================================================================

alter table public.agencias enable row level security;
alter table public.asesores_negocio enable row level security;
alter table public.clientes enable row level security;
alter table public.creditos enable row level security;
alter table public.creditos_preaprobados enable row level security;
alter table public.campanas_activas enable row level security;
alter table public.cartera_diaria enable row level security;
alter table public.cartera_vencida enable row level security;
alter table public.solicitudes_credito enable row level security;
alter table public.solicitudes_documentos enable row level security;
alter table public.consultas_buro enable row level security;
alter table public.acciones_cobranza enable row level security;
alter table public.alertas_cartera enable row level security;
alter table public.solicitudes_notas_internas enable row level security;

-- Asesor: lee su propio perfil
create policy "asesor_lee_su_perfil"
  on public.asesores_negocio for select
  using (user_id = auth.uid());

-- Cartera diaria: operador ve/edita solo su cartera
create policy "asesor_cartera_select"
  on public.cartera_diaria for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_cartera_update"
  on public.cartera_diaria for update
  using (asesor_id = public.current_asesor_id())
  with check (asesor_id = public.current_asesor_id());

-- Clientes: lectura si están en cartera del asesor o en solicitudes propias
create policy "asesor_clientes_select"
  on public.clientes for select
  using (
    exists (
      select 1 from public.cartera_diaria cd
      where cd.cliente_id = clientes.id
        and cd.asesor_id = public.current_asesor_id()
    )
    or exists (
      select 1 from public.solicitudes_credito sc
      where sc.cliente_id = clientes.id
        and sc.asesor_id = public.current_asesor_id()
    )
  );

-- Solicitudes: CRUD del asesor dueño
create policy "asesor_solicitudes_select"
  on public.solicitudes_credito for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_solicitudes_insert"
  on public.solicitudes_credito for insert
  with check (asesor_id = public.current_asesor_id());

create policy "asesor_solicitudes_update"
  on public.solicitudes_credito for update
  using (asesor_id = public.current_asesor_id())
  with check (asesor_id = public.current_asesor_id());

-- Alertas del asesor
create policy "asesor_alertas_select"
  on public.alertas_cartera for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_alertas_update"
  on public.alertas_cartera for update
  using (asesor_id = public.current_asesor_id())
  with check (asesor_id = public.current_asesor_id());

-- Realtime (opcional, habilitar en dashboard para tablas clave)
-- alter publication supabase_realtime add table public.cartera_diaria;
-- alter publication supabase_realtime add table public.solicitudes_credito;
-- alter publication supabase_realtime add table public.alertas_cartera;
