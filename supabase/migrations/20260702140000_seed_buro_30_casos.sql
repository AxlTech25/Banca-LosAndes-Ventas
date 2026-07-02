-- Buró y datos de los 30 casos del enunciado ENUNCIADOS_30_CASOS_CREDITO_FLUJO_MOVIL.

insert into public.clientes (
  numero_documento,
  nombres,
  apellidos,
  telefono,
  tipo_negocio,
  nombre_negocio,
  antiguedad_negocio_meses,
  ingresos_estimados,
  gastos_mensuales
)
values
  ('41336036', 'Lisístrata', 'Ramos', '964110224', 'Comercio', 'Variedades Lisistrata', 52, 4100, 1700),
  ('41552052', 'Filoctetes', 'Cruz', '964110225', 'Restaurante', 'Cevicheria Filoctetes', 18, 3800, 2200),
  ('41888088', 'Calirroe', 'Mendoza', '964110226', 'Calzado', 'Calzados Calirroe', 34, 5000, 2600),
  ('42220022', 'Tucídides', 'Quispe', '964110227', 'Ferreteria', 'Ferreteria Tucidides', 40, 6200, 2900),
  ('43337037', 'Aquiles', 'Mamani', '964110228', 'Comercio', 'Comercial Aquiles', 60, 9000, 3600),
  ('41884084', 'Medea', 'Apaza', '964110229', 'Bodega', 'Bodega Medea', 22, 1800, 1100),
  ('43334034', 'Esquines', 'Rojas', '964110230', 'Transporte', 'Fletes Esquines', 30, 7000, 3200)
on conflict (numero_documento) do update set
  nombres = excluded.nombres,
  apellidos = excluded.apellidos,
  telefono = excluded.telefono,
  tipo_negocio = excluded.tipo_negocio,
  nombre_negocio = excluded.nombre_negocio,
  antiguedad_negocio_meses = excluded.antiguedad_negocio_meses,
  ingresos_estimados = excluded.ingresos_estimados,
  gastos_mensuales = excluded.gastos_mensuales,
  updated_at = now();

update public.clientes c
set
  calificacion_sbs = v.calificacion_sbs,
  buro_entidades_externas = v.entidades,
  buro_deuda_externa_pen = v.deuda_total,
  buro_mayor_deuda_externa = v.mayor_deuda,
  buro_dias_mora_externa = v.dias_mora,
  updated_at = now()
from (
  values
    ('40118120', 'Normal', 1, 4500::numeric, 4500::numeric, 0, 1),
    ('41223341', 'Normal', 2, 12000::numeric, 7200::numeric, 0, 2),
    ('42330336', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 3),
    ('43440349', 'Normal', 2, 14000::numeric, 8400::numeric, 0, 4),
    ('40556071', 'Normal', 2, 12000::numeric, 7200::numeric, 0, 5),
    ('41669066', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 6),
    ('43773379', 'Normal', 2, 14000::numeric, 8400::numeric, 0, 7),
    ('40886086', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 8),
    ('41990091', 'Normal', 2, 12000::numeric, 7200::numeric, 0, 9),
    ('43003039', 'Normal', 2, 14000::numeric, 8400::numeric, 0, 10),
    ('40110010', 'Normal', 1, 4500::numeric, 4500::numeric, 0, 11),
    ('41226021', 'Normal', 2, 12000::numeric, 7200::numeric, 0, 12),
    ('43336033', 'Normal', 0, 0::numeric, 0::numeric, 0, 13),
    ('40550055', 'Deficiente', 2, 16000::numeric, 9600::numeric, 45, 14),
    ('41669166', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 15),
    ('43880088', 'CPP', 1, 9000::numeric, 9000::numeric, 20, 16),
    ('40119019', 'Normal', 2, 14000::numeric, 8400::numeric, 0, 17),
    ('41226126', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 18),
    ('43339033', 'Normal', 0, 0::numeric, 0::numeric, 0, 19),
    ('40556056', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 20),
    ('43889089', 'Normal', 2, 14000::numeric, 8400::numeric, 0, 21),
    ('41003001', 'Normal', 2, 12000::numeric, 7200::numeric, 0, 22),
    ('40115011', 'Normal', 2, 12000::numeric, 7200::numeric, 0, 23),
    ('41336036', 'Normal', 1, 6000::numeric, 6000::numeric, 0, 24),
    ('41552052', 'CPP', 2, 18000::numeric, 10800::numeric, 15, 25),
    ('41888088', 'CPP', 1, 9000::numeric, 9000::numeric, 20, 26),
    ('42220022', 'CPP', 2, 18000::numeric, 10800::numeric, 15, 27),
    ('43337037', 'Perdida', 4, 40000::numeric, 22000::numeric, 210, 28),
    ('41884084', 'Dudoso', 3, 25000::numeric, 12000::numeric, 95, 29),
    ('43334034', 'Dudoso', 3, 25000::numeric, 12000::numeric, 95, 30)
) as v(dni, calificacion_sbs, entidades, deuda_total, mayor_deuda, dias_mora, caso_num)
where c.numero_documento = v.dni;

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
select
  c.numero_documento,
  c.id,
  c.calificacion_sbs,
  c.buro_entidades_externas,
  c.buro_deuda_externa_pen,
  c.buro_mayor_deuda_externa,
  c.buro_dias_mora_externa,
  'Caso ' || v.caso_num::text || ' — ' || c.nombres || ' ' || c.apellidos
from public.clientes c
join (
  values
    ('40118120', 1), ('41223341', 2), ('42330336', 3), ('43440349', 4),
    ('40556071', 5), ('41669066', 6), ('43773379', 7), ('40886086', 8),
    ('41990091', 9), ('43003039', 10), ('40110010', 11), ('41226021', 12),
    ('43336033', 13), ('40550055', 14), ('41669166', 15), ('43880088', 16),
    ('40119019', 17), ('41226126', 18), ('43339033', 19), ('40556056', 20),
    ('43889089', 21), ('41003001', 22), ('40115011', 23), ('41336036', 24),
    ('41552052', 25), ('41888088', 26), ('42220022', 27), ('43337037', 28),
    ('41884084', 29), ('43334034', 30)
) as v(dni, caso_num) on v.dni = c.numero_documento
on conflict (numero_documento) do update set
  cliente_id = excluded.cliente_id,
  calificacion_sbs = excluded.calificacion_sbs,
  entidades_con_deuda = excluded.entidades_con_deuda,
  deuda_total_pen = excluded.deuda_total_pen,
  mayor_deuda = excluded.mayor_deuda,
  dias_mayor_mora = excluded.dias_mayor_mora,
  notas = excluded.notas,
  updated_at = now();

insert into public.lista_negra (numero_documento, motivo, fuente)
values (
  '43337037',
  'Registrado en lista de inhabilitados del sistema financiero (Caso 28)',
  'inhabilitados'
)
on conflict (numero_documento) do update set
  motivo = excluded.motivo,
  fuente = excluded.fuente,
  activo = true;
