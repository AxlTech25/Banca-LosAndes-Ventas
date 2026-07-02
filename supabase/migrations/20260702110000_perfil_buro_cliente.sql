-- Perfil de buró por DNI/cliente (reemplaza simulación por último dígito).

create table if not exists public.perfil_buro_cliente (
  numero_documento varchar(15) primary key,
  cliente_id uuid references public.clientes (id) on delete set null,
  calificacion_sbs varchar(20) not null default 'Normal',
  entidades_con_deuda integer not null default 0,
  deuda_total_pen numeric(12, 2) not null default 0,
  mayor_deuda numeric(12, 2) not null default 0,
  dias_mayor_mora integer not null default 0,
  notas text,
  updated_at timestamptz not null default now()
);

alter table public.perfil_buro_cliente enable row level security;

drop policy if exists "asesor_perfil_buro_select" on public.perfil_buro_cliente;
create policy "asesor_perfil_buro_select"
  on public.perfil_buro_cliente for select
  to authenticated
  using (true);

insert into public.perfil_buro_cliente (
  numero_documento,
  cliente_id,
  calificacion_sbs,
  entidades_con_deuda,
  deuda_total_pen,
  mayor_deuda,
  dias_mayor_mora,
  notas
)
values
  (
    '41226126',
    (select id from public.clientes where numero_documento = '41226126' limit 1),
    'Normal',
    1,
    6000,
    6000,
    0,
    'Caso 18 — Antigona Flores'
  ),
  (
    '43337037',
    (select id from public.clientes where numero_documento = '43337037' limit 1),
    'Perdida',
    4,
    40000,
    22000,
    210,
    'Caso 28 — Aquiles Mamani'
  ),
  (
    '41884084',
    (select id from public.clientes where numero_documento = '41884084' limit 1),
    'Dudoso',
    3,
    25000,
    12000,
    95,
    'Caso 29 — Medea Apaza'
  ),
  (
    '43334034',
    (select id from public.clientes where numero_documento = '43334034' limit 1),
    'Dudoso',
    3,
    25000,
    12000,
    95,
    'Caso 30 — Esquines Rojas'
  )
on conflict (numero_documento) do update set
  cliente_id = excluded.cliente_id,
  calificacion_sbs = excluded.calificacion_sbs,
  entidades_con_deuda = excluded.entidades_con_deuda,
  deuda_total_pen = excluded.deuda_total_pen,
  mayor_deuda = excluded.mayor_deuda,
  dias_mayor_mora = excluded.dias_mayor_mora,
  notas = excluded.notas,
  updated_at = now();

create or replace function public.consultar_buro_por_cliente(
  p_dni text,
  p_cliente_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_dni text;
  v_perfil record;
  v_cliente_id uuid;
  v_calificacion text;
  v_agg record;
begin
  v_dni := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');

  if length(v_dni) < 8 then
    raise exception 'DNI invalido: %', p_dni;
  end if;

  select *
  into v_perfil
  from public.perfil_buro_cliente
  where numero_documento = v_dni;

  if found then
    return jsonb_build_object(
      'calificacion_sbs', v_perfil.calificacion_sbs,
      'entidades_con_deuda', v_perfil.entidades_con_deuda,
      'deuda_total_pen', v_perfil.deuda_total_pen,
      'mayor_deuda', v_perfil.mayor_deuda,
      'dias_mayor_mora', v_perfil.dias_mayor_mora,
      'origen', 'perfil_buro_cliente'
    );
  end if;

  select c.id, c.calificacion_sbs
  into v_cliente_id, v_calificacion
  from public.clientes c
  where c.numero_documento = v_dni
     or (p_cliente_id is not null and c.id = p_cliente_id)
  order by case when c.numero_documento = v_dni then 0 else 1 end
  limit 1;

  if v_cliente_id is not null then
    select
      count(*) filter (where cr.saldo_actual > 0)::integer as entidades,
      coalesce(sum(cr.saldo_actual), 0) as deuda_total,
      coalesce(max(cr.saldo_actual), 0) as mayor_deuda,
      coalesce(max(cr.dias_mora), 0)::integer as max_mora
    into v_agg
    from public.creditos cr
    where cr.cliente_id = v_cliente_id;

    return jsonb_build_object(
      'calificacion_sbs', coalesce(nullif(trim(v_calificacion), ''), 'Normal'),
      'entidades_con_deuda', coalesce(v_agg.entidades, 0),
      'deuda_total_pen', coalesce(v_agg.deuda_total, 0),
      'mayor_deuda', coalesce(v_agg.mayor_deuda, 0),
      'dias_mayor_mora', coalesce(v_agg.max_mora, 0),
      'origen', 'creditos_internos'
    );
  end if;

  return jsonb_build_object(
    'calificacion_sbs', 'Normal',
    'entidades_con_deuda', 0,
    'deuda_total_pen', 0,
    'mayor_deuda', 0,
    'dias_mayor_mora', 0,
    'origen', 'sin_registro'
  );
end;
$$;

grant execute on function public.consultar_buro_por_cliente(text, uuid)
  to authenticated;

-- Compatibilidad: delegar al lookup por cliente/DNI (sin último dígito).
create or replace function public.consultar_buro_simulado_por_dni(p_dni text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.consultar_buro_por_cliente(p_dni, null::uuid);
$$;

grant execute on function public.consultar_buro_simulado_por_dni(text)
  to authenticated;
