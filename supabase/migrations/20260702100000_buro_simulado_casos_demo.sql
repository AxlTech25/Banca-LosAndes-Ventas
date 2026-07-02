-- Buró simulado por DNI de casos de prueba (prioridad sobre ultimo digito).

create table if not exists public.buro_simulado_demo (
  numero_documento varchar(15) primary key,
  calificacion_sbs varchar(20) not null,
  entidades_con_deuda integer not null default 0,
  deuda_total_pen numeric(12, 2) not null default 0,
  mayor_deuda numeric(12, 2) not null default 0,
  dias_mayor_mora integer not null default 0
);

alter table public.buro_simulado_demo enable row level security;

create policy "asesor_buro_demo_select"
  on public.buro_simulado_demo for select
  to authenticated
  using (true);

insert into public.buro_simulado_demo (
  numero_documento,
  calificacion_sbs,
  entidades_con_deuda,
  deuda_total_pen,
  mayor_deuda,
  dias_mayor_mora
)
values
  ('41226126', 'Normal', 1, 6000, 6000, 0),
  ('43337037', 'Perdida', 4, 40000, 22000, 210),
  ('41884084', 'Dudoso', 3, 25000, 12000, 95),
  ('43334034', 'Dudoso', 3, 25000, 12000, 95)
on conflict (numero_documento) do update set
  calificacion_sbs = excluded.calificacion_sbs,
  entidades_con_deuda = excluded.entidades_con_deuda,
  deuda_total_pen = excluded.deuda_total_pen,
  mayor_deuda = excluded.mayor_deuda,
  dias_mayor_mora = excluded.dias_mayor_mora;

create or replace function public.consultar_buro_simulado_por_dni(p_dni text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_digits text;
  v_demo record;
  v_digit integer;
begin
  v_digits := regexp_replace(coalesce(p_dni, ''), '\D', '', 'g');

  if length(v_digits) >= 1 then
    select *
    into v_demo
    from public.buro_simulado_demo
    where numero_documento = v_digits;

    if found then
      return jsonb_build_object(
        'calificacion_sbs', v_demo.calificacion_sbs,
        'entidades_con_deuda', v_demo.entidades_con_deuda,
        'deuda_total_pen', v_demo.deuda_total_pen,
        'mayor_deuda', v_demo.mayor_deuda,
        'dias_mayor_mora', v_demo.dias_mayor_mora,
        'origen', 'demo_caso'
      );
    end if;
  end if;

  if length(v_digits) < 1 then
    return jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 1200,
      'mayor_deuda', 1200,
      'dias_mayor_mora', 0,
      'origen', 'ultimo_digito'
    );
  end if;

  v_digit := (right(v_digits, 1))::integer;

  return case v_digit
    when 0 then jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 4500,
      'mayor_deuda', 4500,
      'dias_mayor_mora', 0,
      'origen', 'ultimo_digito'
    )
    when 1 then jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 2,
      'deuda_total_pen', 3200,
      'mayor_deuda', 2000,
      'dias_mayor_mora', 0,
      'origen', 'ultimo_digito'
    )
    when 2 then jsonb_build_object(
      'calificacion_sbs', 'CPP',
      'entidades_con_deuda', 2,
      'deuda_total_pen', 4800,
      'mayor_deuda', 3200,
      'dias_mayor_mora', 12,
      'origen', 'ultimo_digito'
    )
    when 3 then jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 2800,
      'mayor_deuda', 2800,
      'dias_mayor_mora', 0,
      'origen', 'ultimo_digito'
    )
    when 4 then jsonb_build_object(
      'calificacion_sbs', 'Deficiente',
      'entidades_con_deuda', 3,
      'deuda_total_pen', 9200,
      'mayor_deuda', 5100,
      'dias_mayor_mora', 45,
      'origen', 'ultimo_digito'
    )
    when 5 then jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 0,
      'deuda_total_pen', 0,
      'mayor_deuda', 0,
      'dias_mayor_mora', 0,
      'origen', 'ultimo_digito'
    )
    when 6 then jsonb_build_object(
      'calificacion_sbs', 'CPP',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 1500,
      'mayor_deuda', 1500,
      'dias_mayor_mora', 5,
      'origen', 'ultimo_digito'
    )
    when 7 then jsonb_build_object(
      'calificacion_sbs', 'Normal',
      'entidades_con_deuda', 1,
      'deuda_total_pen', 1200,
      'mayor_deuda', 1200,
      'dias_mayor_mora', 0,
      'origen', 'ultimo_digito'
    )
    when 8 then jsonb_build_object(
      'calificacion_sbs', 'Dudoso',
      'entidades_con_deuda', 4,
      'deuda_total_pen', 15000,
      'mayor_deuda', 8000,
      'dias_mayor_mora', 90,
      'origen', 'ultimo_digito'
    )
    else jsonb_build_object(
      'calificacion_sbs', 'Perdida',
      'entidades_con_deuda', 5,
      'deuda_total_pen', 22000,
      'mayor_deuda', 12000,
      'dias_mayor_mora', 180,
      'origen', 'ultimo_digito'
    )
  end;
end;
$$;

grant execute on function public.consultar_buro_simulado_por_dni(text)
  to authenticated;
