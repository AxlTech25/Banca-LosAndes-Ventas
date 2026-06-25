-- =============================================================================
-- Verificación del entorno de pruebas
-- =============================================================================

-- 1) Usuarios y perfiles
select
  an.codigo_empleado,
  u.email,
  an.perfil,
  an.activo,
  case when u.email_confirmed_at is not null then 'ok' else 'sin confirmar' end as auth
from public.asesores_negocio an
join auth.users u on u.id = an.user_id
order by an.codigo_empleado;

-- 2) Cartera del día por asesor
select
  an.codigo_empleado,
  c.nombres || ' ' || c.apellidos as cliente,
  cd.tipo_gestion,
  cd.estado_visita,
  cd.score_prioridad
from public.cartera_diaria cd
join public.asesores_negocio an on an.id = cd.asesor_id
join public.clientes c on c.id = cd.cliente_id
where cd.fecha_asignacion = current_date
order by an.codigo_empleado, cd.score_prioridad desc;

-- 3) Solicitudes del mes (productividad M11)
select
  an.codigo_empleado,
  sc.numero_expediente,
  sc.estado,
  sc.monto_solicitado,
  sc.monto_aprobado,
  sc.created_at::date
from public.solicitudes_credito sc
join public.asesores_negocio an on an.id = sc.asesor_id
where sc.created_at >= date_trunc('month', current_date)
  and sc.estado <> 'borrador'
order by an.codigo_empleado, sc.created_at;

-- 4) Alertas sin leer
select
  an.codigo_empleado,
  count(*) filter (where not ac.leida) as alertas_pendientes
from public.alertas_cartera ac
join public.asesores_negocio an on an.id = ac.asesor_id
group by an.codigo_empleado;

-- 5) Realtime (debe estar en publication supabase_realtime)
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and tablename in ('solicitudes_credito', 'cartera_diaria', 'alertas_cartera')
order by tablename;
