-- Datos de demostración — Banco Los Andes / Banco_DBAndes
-- Ejecutar DESPUÉS de scripts/seed_test_users.sql
--
-- Operador principal: Juan Perez (104592) — login Demo2026!
-- =============================================================================

-- Agencia
insert into public.agencias (id, nombre, region, lat, lng, activa)
values (
  'a1111111-1111-4111-8111-111111111111',
  'Agencia Los Andes Lima Centro',
  'Lima',
  -12.046374,
  -77.042793,
  true
)
on conflict (id) do nothing;

-- Clientes
insert into public.clientes (
  id, numero_documento, nombres, apellidos, telefono, direccion,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses, lat, lng, calificacion_sbs
) values
  (
    'c3333333-3333-4333-8333-333333333301',
    '45678901', 'Maria', 'Quispe', '987654321',
    'Av. Grau 120, Lima', 'Comercio', 'Bodega Don Pepe', 36,
    -12.050100, -77.035400, 'Normal'
  ),
  (
    'c3333333-3333-4333-8333-333333333302',
    '12345678', 'Carlos', 'Rojas', '912345678',
    'Jr. Union 45, Lima', 'Servicios', 'Taller Mecanico CR', 48,
    -12.055200, -77.040100, 'CPP'
  ),
  (
    'c3333333-3333-4333-8333-333333333303',
    '87654321', 'Ana', 'Torres', '998877665',
    'Av. Brasil 890, Lima', 'Comercio', 'Polleria Ana', 24,
    -12.048800, -77.038500, 'Normal'
  )
on conflict (id) do update set
  lat = excluded.lat,
  lng = excluded.lng,
  antiguedad_negocio_meses = excluded.antiguedad_negocio_meses,
  nombres = excluded.nombres,
  apellidos = excluded.apellidos;

-- Créditos
insert into public.creditos (
  id, cliente_id, asesor_id, agencia_id, producto,
  monto_desembolsado, plazo_meses, tea, estado, saldo_actual,
  cuotas_total, cuotas_pagadas, dias_mora, fecha_desembolso
) values
  (
    'd4444444-4444-4444-8444-444444444401',
    'c3333333-3333-4333-8333-333333333301',
    'b2222222-2222-4222-8222-222222222222',
    'a1111111-1111-4111-8111-111111111111',
    'Microcredito comercio', 8000, 12, 68.5, 'vigente', 4200,
    12, 8, 0, current_date - interval '8 months'
  ),
  (
    'd4444444-4444-4444-8444-444444444402',
    'c3333333-3333-4333-8333-333333333302',
    'b2222222-2222-4222-8222-222222222222',
    'a1111111-1111-4111-8111-111111111111',
    'Microcredito servicios', 15000, 18, 72.0, 'vencido', 9800,
    18, 11, 35, current_date - interval '14 months'
  )
on conflict (id) do nothing;

-- Preaprobado vigente (Maria)
insert into public.creditos_preaprobados (
  cliente_id, asesor_id, monto_maximo, plazo_sugerido_meses,
  tea_referencial, score_confianza, vigente, fecha_calculo, fecha_vencimiento
) values (
  'c3333333-3333-4333-8333-333333333301',
  'b2222222-2222-4222-8222-222222222222',
  12000, 12, 68.5, 82, true, current_date, current_date + interval '30 days'
);

-- Cartera del día (fecha actual)
insert into public.cartera_diaria (
  asesor_id, cliente_id, agencia_id, credito_id, fecha_asignacion,
  tipo_gestion, prioridad, score_prioridad
) values
  (
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333301',
    'a1111111-1111-4111-8111-111111111111',
    'd4444444-4444-4444-8444-444444444401',
    current_date, 'RENOVACION', 'media', 35
  ),
  (
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333302',
    'a1111111-1111-4111-8111-111111111111',
    'd4444444-4444-4444-8444-444444444402',
    current_date, 'RECUPERACION_MORA', 'alta', 75
  ),
  (
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333303',
    'a1111111-1111-4111-8111-111111111111',
    null,
    current_date, 'DESERTOR', 'baja', 15
  )
  on conflict (asesor_id, cliente_id, fecha_asignacion) do update set
  tipo_gestion = excluded.tipo_gestion,
  prioridad = excluded.prioridad,
  score_prioridad = excluded.score_prioridad;

-- Visita demo con GPS (M11 — monitor de cobertura)
update public.cartera_diaria
set
  estado_visita = 'visitado',
  resultado_visita = 'Visitado',
  timestamp_visita = now() - interval '1 hour',
  lat_visita = -12.050100,
  lng_visita = -77.035400
where asesor_id = 'b2222222-2222-4222-8222-222222222222'
  and cliente_id = 'c3333333-3333-4333-8333-333333333301'
  and fecha_asignacion = current_date;

-- Cartera vencida (M8 demo - Carlos Rojas)
insert into public.cartera_vencida (
  id, asesor_id, cliente_id, credito_id, dias_mora, monto_vencido, fecha_ultimo_contacto
) values (
  'c7777777-7777-4777-8777-777777777701',
  'b2222222-2222-4222-8222-222222222222',
  'c3333333-3333-4333-8333-333333333302',
  'd4444444-4444-4444-8444-444444444402',
  35,
  1850.00,
  current_date - interval '12 days'
)
on conflict (id) do update set
  dias_mora = excluded.dias_mora,
  monto_vencido = excluded.monto_vencido,
  fecha_ultimo_contacto = excluded.fecha_ultimo_contacto;

-- Alertas de cartera (HU-14)
insert into public.alertas_cartera (
  asesor_id, cliente_id, tipo_alerta, mensaje, leida
) values
  (
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333302',
    'primer_dia_mora',
    'Carlos Rojas registro su primer dia de mora. Gestion preventiva recomendada.',
    false
  ),
  (
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333302',
    'mora_30d',
    'Carlos Rojas supero 30 dias de mora. Priorizar visita de cobranza.',
    false
  ),
  (
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333301',
    'pago_total',
    'Maria Quispe cancelo su cuota del periodo.',
    true
  );

-- Campanas activas (HU-16 / M4)
insert into public.campanas_activas (
  id, asesor_id, cliente_id, tipo_campana, monto_ofertado, activa, fecha_vencimiento
) values
  (
    'e5555555-5555-4555-8555-555555555501',
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333301',
    'RENOVACION',
    12000,
    true,
    current_date + interval '15 days'
  ),
  (
    'e5555555-5555-4555-8555-555555555502',
    'b2222222-2222-4222-8222-222222222222',
    'c3333333-3333-4333-8333-333333333302',
    'AMPLIACION',
    5000,
    true,
    current_date + interval '7 days'
  )
on conflict (id) do update set
  monto_ofertado = excluded.monto_ofertado,
  activa = excluded.activa,
  fecha_vencimiento = excluded.fecha_vencimiento;

-- Solicitud demo enviada (M6)
insert into public.solicitudes_credito (
  id, numero_expediente, asesor_id, cliente_id, agencia_id,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
  ingresos_estimados, monto_solicitado, plazo_meses,
  destino_credito, cuota_estimada, tea_referencial, estado
) values (
  'f6666666-6666-4666-8666-666666666601',
  'SOL-DEMO-001',
  'b2222222-2222-4222-8222-222222222222',
  'c3333333-3333-4333-8333-333333333301',
  'a1111111-1111-4111-8111-111111111111',
  'Comercio', 'Bodega Don Pepe', 36,
  3500, 10000, 12,
  'Capital de trabajo', 950.25, 68.5, 'transmitida'
)
on conflict (id) do update set
  estado = excluded.estado,
  monto_solicitado = excluded.monto_solicitado;

insert into public.solicitudes_notas_internas (
  solicitud_id, asesor_id, contenido
) values (
  'f6666666-6666-4666-8666-666666666601',
  'b2222222-2222-4222-8222-222222222222',
  'Solicitud transmitida al back office desde campo.'
);

-- Solicitud en analisis (M7 demo)
insert into public.solicitudes_credito (
  id, numero_expediente, asesor_id, cliente_id, agencia_id,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
  ingresos_estimados, monto_solicitado, plazo_meses,
  destino_credito, cuota_estimada, tea_referencial,
  estado, analista_asignado
) values (
  'f6666666-6666-4666-8666-666666666602',
  'SOL-DEMO-002',
  'b2222222-2222-4222-8222-222222222222',
  'c3333333-3333-4333-8333-333333333302',
  'a1111111-1111-4111-8111-111111111111',
  'Servicios', 'Taller Mecanico CR', 48,
  4200, 8000, 18,
  'Ampliacion de capital', 620.00, 72.0,
  'en_analisis', 'Luis Mendoza'
)
on conflict (id) do update set
  estado = excluded.estado,
  analista_asignado = excluded.analista_asignado;

-- Solicitud aprobada (M7 demo — Maria Quispe)
insert into public.solicitudes_credito (
  id, numero_expediente, asesor_id, cliente_id, agencia_id,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
  ingresos_estimados, monto_solicitado, monto_aprobado, plazo_meses,
  destino_credito, cuota_estimada, tea_referencial,
  estado, analista_asignado, condicion_adicional
) values (
  'f6666666-6666-4666-8666-666666666603',
  'SOL-DEMO-003',
  'b2222222-2222-4222-8222-222222222222',
  'c3333333-3333-4333-8333-333333333301',
  'a1111111-1111-4111-8111-111111111111',
  'Comercio', 'Bodega Don Pepe', 36,
  3500, 6000, 5500, 12,
  'Capital de trabajo', 520.00, 68.5,
  'aprobada', 'Carmen Vela', 'Visita de seguimiento a los 30 dias'
)
on conflict (id) do update set
  estado = excluded.estado,
  monto_aprobado = excluded.monto_aprobado;

-- Solicitud desembolsada (M9 demo)
insert into public.solicitudes_credito (
  id, numero_expediente, asesor_id, cliente_id, agencia_id,
  tipo_negocio, nombre_negocio, antiguedad_negocio_meses,
  ingresos_estimados, monto_solicitado, monto_aprobado, plazo_meses,
  destino_credito, cuota_estimada, tea_referencial,
  estado, analista_asignado, updated_at
) values (
  'f6666666-6666-4666-8666-666666666604',
  'SOL-DEMO-004',
  'b2222222-2222-4222-8222-222222222222',
  'c3333333-3333-4333-8333-333333333301',
  'a1111111-1111-4111-8111-111111111111',
  'Comercio', 'Bodega Don Pepe', 36,
  3500, 10000, 10000, 12,
  'Capital de trabajo', 950.25, 68.5,
  'desembolsada', 'Luis Mendoza', now()
)
on conflict (id) do update set
  estado = excluded.estado,
  monto_aprobado = excluded.monto_aprobado,
  updated_at = excluded.updated_at;

-- Verificación rápida
-- select * from asesores_negocio;
-- select cd.*, c.nombres from cartera_diaria cd join clientes c on c.id = cd.cliente_id where fecha_asignacion = current_date;

-- M11 — Probar reportes: login como supervisor 301001 / Demo2026!
-- (Ver supabase/scripts/README.md)
