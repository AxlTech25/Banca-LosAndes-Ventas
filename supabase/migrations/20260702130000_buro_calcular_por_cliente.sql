-- Buró calculado por cliente: datos explícitos en clientes + créditos internos + fórmula por perfil.

alter table public.clientes
  add column if not exists buro_entidades_externas integer,
  add column if not exists buro_deuda_externa_pen numeric(12, 2),
  add column if not exists buro_mayor_deuda_externa numeric(12, 2),
  add column if not exists buro_dias_mora_externa integer default 0;

-- Casos del curso con buró esperado documentado.
update public.clientes c
set
  calificacion_sbs = v.calificacion_sbs,
  buro_entidades_externas = v.entidades,
  buro_deuda_externa_pen = v.deuda_total,
  buro_mayor_deuda_externa = v.mayor_deuda,
  buro_dias_mora_externa = v.dias_mora
from (
  values
    ('41226126', 'Normal', 1, 6000::numeric, 6000::numeric, 0),
    ('43337037', 'Perdida', 4, 40000::numeric, 22000::numeric, 210),
    ('41884084', 'Dudoso', 3, 25000::numeric, 12000::numeric, 95),
    ('43334034', 'Dudoso', 3, 25000::numeric, 12000::numeric, 95)
) as v(dni, calificacion_sbs, entidades, deuda_total, mayor_deuda, dias_mora)
where c.numero_documento = v.dni;

create or replace function public.peor_calificacion_sbs(p_a text, p_b text)
returns text
language sql
immutable
as $$
  select case
    when coalesce(
      case upper(trim(p_a))
        when 'NORMAL' then 1
        when 'CPP' then 2
        when 'DEFICIENTE' then 3
        when 'DUDOSO' then 4
        when 'PERDIDA' then 5
        else 1
      end, 1
    ) >= coalesce(
      case upper(trim(p_b))
        when 'NORMAL' then 1
        when 'CPP' then 2
        when 'DEFICIENTE' then 3
        when 'DUDOSO' then 4
        when 'PERDIDA' then 5
        else 1
      end, 1
    ) then coalesce(nullif(trim(p_a), ''), 'Normal')
    else coalesce(nullif(trim(p_b), ''), 'Normal')
  end;
$$;

create or replace function public.calcular_buro_externo_cliente(p_cliente_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  c public.clientes%rowtype;
  v_seed integer;
  v_ingresos numeric;
  v_rating text;
  v_entidades integer;
  v_deuda numeric;
  v_mayor numeric;
  v_mora integer;
begin
  select *
  into c
  from public.clientes
  where id = p_cliente_id;

  if not found then
    return null;
  end if;

  if c.buro_deuda_externa_pen is not null then
    return jsonb_build_object(
      'calificacion_sbs', coalesce(nullif(trim(c.calificacion_sbs), ''), 'Normal'),
      'entidades_con_deuda', coalesce(c.buro_entidades_externas, 0),
      'deuda_total_pen', c.buro_deuda_externa_pen,
      'mayor_deuda', coalesce(c.buro_mayor_deuda_externa, c.buro_deuda_externa_pen),
      'dias_mayor_mora', coalesce(c.buro_dias_mora_externa, 0),
      'origen', 'cliente_configurado'
    );
  end if;

  v_seed := abs(hashtext(coalesce(c.numero_documento, c.id::text)));
  v_ingresos := greatest(coalesce(c.ingresos_estimados, 3500), 1500);

  v_rating := coalesce(
    nullif(trim(c.calificacion_sbs), ''),
    case
      when (v_seed % 20) <= 14 then 'Normal'
      when (v_seed % 20) in (15, 16) then 'CPP'
      when (v_seed % 20) = 17 then 'Deficiente'
      when (v_seed % 20) = 18 then 'Dudoso'
      else 'Perdida'
    end
  );

  case upper(v_rating)
    when 'CPP' then
      v_entidades := 2;
      v_deuda := round(v_ingresos * 0.85 / 100) * 100;
      v_mayor := round(v_deuda * 0.65 / 100) * 100;
      v_mora := 5 + (v_seed % 11);
    when 'DEFICIENTE' then
      v_entidades := 3;
      v_deuda := round(v_ingresos * 1.15 / 100) * 100;
      v_mayor := round(v_deuda * 0.55 / 100) * 100;
      v_mora := 30 + (v_seed % 21);
    when 'DUDOSO' then
      v_entidades := 3 + (v_seed % 2);
      v_deuda := round(v_ingresos * 2.7 / 100) * 100;
      v_mayor := round(v_deuda * 0.48 / 100) * 100;
      v_mora := 80 + (v_seed % 21);
    when 'PERDIDA' then
      v_entidades := 4 + (v_seed % 2);
      v_deuda := round(v_ingresos * 4.3 / 100) * 100;
      v_mayor := round(v_deuda * 0.55 / 100) * 100;
      v_mora := 180 + (v_seed % 41);
    else
      v_entidades := 1;
      v_deuda := round(v_ingresos * 0.652 / 100) * 100;
      v_mayor := v_deuda;
      v_mora := 0;
      v_rating := 'Normal';
  end case;

  return jsonb_build_object(
    'calificacion_sbs', v_rating,
    'entidades_con_deuda', v_entidades,
    'deuda_total_pen', v_deuda,
    'mayor_deuda', v_mayor,
    'dias_mayor_mora', v_mora,
    'origen', 'perfil_calculado'
  );
end;
$$;

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
  c public.clientes%rowtype;
  v_ext jsonb;
  v_int_entidades integer := 0;
  v_int_deuda numeric := 0;
  v_int_mayor numeric := 0;
  v_int_mora integer := 0;
  v_rating_ext text;
  v_rating_int text;
  v_origen text;
begin
  v_dni := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');

  if length(v_dni) < 8 then
    raise exception 'DNI invalido: %', p_dni;
  end if;

  select *
  into c
  from public.clientes cli
  where cli.numero_documento = v_dni
     or (p_cliente_id is not null and cli.id = p_cliente_id)
  order by case when cli.numero_documento = v_dni then 0 else 1 end
  limit 1;

  if not found then
    return jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 0,
      'deuda_total_pen', 0,
      'mayor_deuda', 0,
      'dias_mayor_mora', 0,
      'origen', 'sin_registro'
    );
  end if;

  v_ext := public.calcular_buro_externo_cliente(c.id);

  select
    count(*) filter (where cr.saldo_actual > 0)::integer,
    coalesce(sum(cr.saldo_actual), 0),
    coalesce(max(cr.saldo_actual), 0),
    coalesce(max(cr.dias_mora), 0)::integer
  into v_int_entidades, v_int_deuda, v_int_mayor, v_int_mora
  from public.creditos cr
  where cr.cliente_id = c.id;

  v_rating_ext := coalesce(v_ext ->> 'calificacion_sbs', 'Normal');
  v_rating_int := case
    when v_int_mora >= 180 or v_int_deuda >= 15000 then 'Perdida'
    when v_int_mora >= 90 then 'Dudoso'
    when v_int_mora >= 45 then 'Deficiente'
    when v_int_mora >= 8 then 'CPP'
    when v_int_deuda > 0 then 'Normal'
    else 'Normal'
  end;

  v_origen := coalesce(v_ext ->> 'origen', 'perfil_calculado');
  if v_int_deuda > 0 then
    v_origen := v_origen || '+creditos_internos';
  end if;

  return jsonb_build_object(
    'calificacion_sbs', public.peor_calificacion_sbs(v_rating_ext, v_rating_int),
    'entidades_con_deuda',
      coalesce((v_ext ->> 'entidades_con_deuda')::integer, 0) + coalesce(v_int_entidades, 0),
    'deuda_total_pen',
      coalesce((v_ext ->> 'deuda_total_pen')::numeric, 0) + coalesce(v_int_deuda, 0),
    'mayor_deuda',
      greatest(
        coalesce((v_ext ->> 'mayor_deuda')::numeric, 0),
        coalesce(v_int_mayor, 0)
      ),
    'dias_mayor_mora',
      greatest(
        coalesce((v_ext ->> 'dias_mayor_mora')::integer, 0),
        coalesce(v_int_mora, 0)
      ),
    'origen', v_origen
  );
end;
$$;

grant execute on function public.calcular_buro_externo_cliente(uuid) to authenticated;
grant execute on function public.consultar_buro_por_cliente(text, uuid) to authenticated;

create or replace function public.consultar_buro_simulado_por_dni(p_dni text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select public.consultar_buro_por_cliente(p_dni, null::uuid);
$$;

grant execute on function public.consultar_buro_simulado_por_dni(text) to authenticated;
