-- Pre-evaluacion casos 28-30: media APTO = 85, capacidad de pago por cuota vs ingreso neto.

create or replace function public.pre_evaluar_solicitud_app_cliente(p_solicitud_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_solicitud record;
  v_gastos numeric;
  v_neto numeric;
  v_cuota numeric;
  v_tea numeric;
  v_plazo integer;
  v_ratio numeric;
  v_carga numeric;
  v_calificacion text;
  v_puntaje integer;
  v_motivo text;
begin
  if not public.es_asesor_activo() then
    raise exception 'Solo asesores activos pueden pre-evaluar.';
  end if;

  select sc.*, c.calificacion_sbs
  into v_solicitud
  from public.solicitudes_credito sc
  join public.clientes c on c.id = sc.cliente_id
  where sc.id = p_solicitud_id
    and sc.origen = 'app_cliente'
    and sc.asesor_id = public.current_asesor_id();

  if not found then
    raise exception 'Solicitud no encontrada o no asignada a usted.';
  end if;

  if coalesce(v_solicitud.antiguedad_negocio_meses, 0) < 6 then
    v_calificacion := 'NO PROCEDE';
    v_puntaje := 15;
    v_motivo := 'El negocio debe tener al menos 6 meses de antiguedad.';
  elsif coalesce(v_solicitud.ingresos_estimados, 0) <= 0 then
    v_calificacion := 'NO PROCEDE';
    v_puntaje := 20;
    v_motivo := 'Ingresos estimados insuficientes para evaluar.';
  else
    v_gastos := coalesce(
      nullif(v_solicitud.gastos_mensuales, 0),
      v_solicitud.ingresos_estimados * 0.4
    );
    v_neto := v_solicitud.ingresos_estimados - v_gastos;

    if v_neto <= 0 then
      v_calificacion := 'NO PROCEDE';
      v_puntaje := 20;
      v_motivo := 'Los gastos mensuales igualan o superan los ingresos.';
    else
      v_plazo := greatest(coalesce(v_solicitud.plazo_meses, 18), 1);
      v_tea := coalesce(v_solicitud.tea_referencial, 43.92);
      v_cuota := coalesce(
        nullif(v_solicitud.cuota_estimada, 0),
        public.estimar_cuota_credito(
          v_solicitud.monto_solicitado,
          v_plazo,
          v_tea
        )
      );
      v_ratio := v_solicitud.monto_solicitado / v_solicitud.ingresos_estimados;
      v_carga := v_cuota / v_neto;

      if v_carga > 1.0 or v_ratio > 5 then
        v_calificacion := 'REVISAR';
        v_puntaje := 60;
        v_motivo :=
          'Capacidad de pago ajustada. La cuota estimada supera el margen disponible. '
          || 'Se recomienda analisis adicional antes del comite.';
      else
        v_calificacion := 'APTO';
        v_puntaje := 85;
        v_motivo := 'Perfil compatible con microcredito comercial. Puede continuar.';
      end if;
    end if;
  end if;

  insert into public.pre_evaluaciones_solicitud (
    solicitud_id, asesor_id, calificacion, puntaje, motivo
  )
  values (
    p_solicitud_id,
    public.current_asesor_id(),
    v_calificacion,
    v_puntaje,
    v_motivo
  )
  on conflict (solicitud_id) do update set
    asesor_id = excluded.asesor_id,
    calificacion = excluded.calificacion,
    puntaje = excluded.puntaje,
    motivo = excluded.motivo,
    created_at = now();

  return jsonb_build_object(
    'calificacion', v_calificacion,
    'puntaje_estimado', v_puntaje,
    'motivo', v_motivo
  );
end;
$$;

create or replace function public.estimar_cuota_credito(
  p_monto numeric,
  p_plazo_meses integer,
  p_tea numeric
)
returns numeric
language plpgsql
immutable
as $$
declare
  v_tasa_mensual numeric;
  v_factor numeric;
begin
  if p_plazo_meses <= 0 then
    return 0;
  end if;

  v_tasa_mensual := p_tea / 100 / 12;
  if v_tasa_mensual <= 0 then
    return p_monto / p_plazo_meses;
  end if;

  v_factor := power(1 + v_tasa_mensual, p_plazo_meses);
  return p_monto * v_tasa_mensual * v_factor / (v_factor - 1);
end;
$$;

grant execute on function public.estimar_cuota_credito(numeric, integer, numeric)
  to authenticated;
