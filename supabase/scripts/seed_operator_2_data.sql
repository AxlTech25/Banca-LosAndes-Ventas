-- =============================================================================
-- Operadores secundarios 105001 (Rosa) y datos M11
-- Requiere: seed_test_users.sql + seed_demo.sql
-- =============================================================================

-- Rosa 105001
insert into public.cartera_diaria (
  asesor_id, cliente_id, agencia_id, credito_id, fecha_asignacion,
  tipo_gestion, prioridad, score_prioridad, estado_visita,
  timestamp_visita, lat_visita, lng_visita
) values
  (
    'b3333333-3333-4333-8333-333333333333',
    'c3333333-3333-4333-8333-333333333303',
    'a1111111-1111-4111-8111-111111111111',
    null, current_date, 'SEGUIMIENTO', 'media', 30,
    'visitado', now() - interval '45 minutes', -12.048800, -77.038500
  ),
  (
    'b3333333-3333-4333-8333-333333333333',
    'c3333333-3333-4333-8333-333333333301',
    'a1111111-1111-4111-8111-111111111111',
    'd4444444-4444-4444-8444-444444444401',
    current_date, 'AMPLIACION', 'media', 42,
    'pendiente', null, null, null
  )
on conflict (asesor_id, cliente_id, fecha_asignacion) do update set
  tipo_gestion = excluded.tipo_gestion,
  score_prioridad = excluded.score_prioridad,
  estado_visita = excluded.estado_visita,
  timestamp_visita = excluded.timestamp_visita,
  lat_visita = excluded.lat_visita,
  lng_visita = excluded.lng_visita;

insert into public.solicitudes_credito (
  id, numero_expediente, asesor_id, cliente_id, agencia_id,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
  ingresos_estimados, monto_solicitado, monto_aprobado, plazo_meses,
  destino_credito, cuota_estimada, tea_referencial,
  estado, created_at, updated_at
) values
  (
    'f6666666-6666-4666-8666-666666666621',
    'SOL-ROSA-001',
    'b3333333-3333-4333-8333-333333333333',
    'c3333333-3333-4333-8333-333333333303',
    'a1111111-1111-4111-8111-111111111111',
    'Comercio', 'Polleria Ana', 24,
    2800, 7000, null, 12,
    'Capital de trabajo', 680.00, 70.0,
    'enviada',
    date_trunc('month', current_date) + interval '2 days',
    date_trunc('month', current_date) + interval '2 days'
  ),
  (
    'f6666666-6666-4666-8666-666666666622',
    'SOL-ROSA-002',
    'b3333333-3333-4333-8333-333333333333',
    'c3333333-3333-4333-8333-333333333301',
    'a1111111-1111-4111-8111-111111111111',
    'Comercio', 'Bodega Don Pepe', 36,
    3500, 4500, 4500, 10,
    'Inventario', 430.00, 68.5,
    'desembolsada',
    date_trunc('month', current_date) + interval '6 days',
    date_trunc('month', current_date) + interval '10 days'
  )
on conflict (id) do update set
  estado = excluded.estado,
  monto_aprobado = excluded.monto_aprobado,
  updated_at = excluded.updated_at;

-- Luis 105002
insert into public.cartera_diaria (
  asesor_id, cliente_id, agencia_id, credito_id, fecha_asignacion,
  tipo_gestion, prioridad, score_prioridad, estado_visita,
  timestamp_visita, lat_visita, lng_visita
) values
  (
    'b8888888-8888-4888-8888-888888888801',
    'c3333333-3333-4333-8333-333333333302',
    'a1111111-1111-4111-8111-111111111111',
    'd4444444-4444-4444-8444-444444444402',
    current_date, 'RENOVACION', 'alta', 55,
    'visitado', now() - interval '20 minutes', -12.055200, -77.040100
  ),
  (
    'b8888888-8888-4888-8888-888888888801',
    'c3333333-3333-4333-8333-333333333303',
    'a1111111-1111-4111-8111-111111111111',
    null, current_date, 'NUEVA_SOLICITUD', 'media', 38,
    'pendiente', null, null, null
  )
on conflict (asesor_id, cliente_id, fecha_asignacion) do update set
  tipo_gestion = excluded.tipo_gestion,
  estado_visita = excluded.estado_visita,
  timestamp_visita = excluded.timestamp_visita,
  lat_visita = excluded.lat_visita,
  lng_visita = excluded.lng_visita;

insert into public.solicitudes_credito (
  id, numero_expediente, asesor_id, cliente_id, agencia_id,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
  ingresos_estimados, monto_solicitado, monto_aprobado, plazo_meses,
  destino_credito, cuota_estimada, tea_referencial,
  estado, created_at, updated_at
) values
  (
    'f6666666-6666-4666-8666-666666666611',
    'SOL-LUIS-001',
    'b8888888-8888-4888-8888-888888888801',
    'c3333333-3333-4333-8333-333333333303',
    'a1111111-1111-4111-8111-111111111111',
    'Comercio', 'Polleria Ana', 24,
    2600, 6500, null, 12,
    'Capital', 640.00, 69.0,
    'enviada',
    date_trunc('month', current_date) + interval '4 days',
    date_trunc('month', current_date) + interval '4 days'
  ),
  (
    'f6666666-6666-4666-8666-666666666612',
    'SOL-LUIS-002',
    'b8888888-8888-4888-8888-888888888801',
    'c3333333-3333-4333-8333-333333333302',
    'a1111111-1111-4111-8111-111111111111',
    'Servicios', 'Taller Mecanico CR', 48,
    4200, 5500, 5500, 12,
    'Equipamiento', 510.00, 72.0,
    'aprobada',
    date_trunc('month', current_date) + interval '9 days',
    date_trunc('month', current_date) + interval '11 days'
  )
on conflict (id) do update set
  estado = excluded.estado,
  monto_aprobado = excluded.monto_aprobado;
