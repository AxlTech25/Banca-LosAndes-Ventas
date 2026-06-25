-- =============================================================================
-- Refresca la cartera del día para operadores demo (104592, 105001, 105002)
-- Ejecutar en SQL Editor cuando la cartera aparece vacía
-- =============================================================================

-- Copia la cartera más reciente de cada asesor al día de hoy
insert into public.cartera_diaria (
  asesor_id, cliente_id, agencia_id, credito_id, fecha_asignacion,
  tipo_gestion, prioridad, score_prioridad, estado_visita
)
select
  cd.asesor_id,
  cd.cliente_id,
  cd.agencia_id,
  cd.credito_id,
  current_date,
  cd.tipo_gestion,
  cd.prioridad,
  cd.score_prioridad,
  'pendiente'
from public.cartera_diaria cd
inner join (
  select asesor_id, max(fecha_asignacion) as max_fecha
  from public.cartera_diaria
  group by asesor_id
) latest
  on latest.asesor_id = cd.asesor_id
 and cd.fecha_asignacion = latest.max_fecha
inner join public.asesores_negocio an on an.id = cd.asesor_id
where an.perfil in ('operador', 'super_operador')
on conflict (asesor_id, cliente_id, fecha_asignacion) do update set
  tipo_gestion = excluded.tipo_gestion,
  score_prioridad = excluded.score_prioridad,
  prioridad = excluded.prioridad,
  estado_visita = excluded.estado_visita;

-- Verificación
select
  an.codigo_empleado,
  count(*) as clientes_hoy
from public.cartera_diaria cd
join public.asesores_negocio an on an.id = cd.asesor_id
where cd.fecha_asignacion = current_date
  and an.perfil in ('operador', 'super_operador')
group by an.codigo_empleado
order by an.codigo_empleado;
