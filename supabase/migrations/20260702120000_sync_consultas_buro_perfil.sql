-- Corrige consultas de buró cacheadas con simulación antigua (último dígito / mock).

update public.consultas_buro cb
set
  calificacion_sbs = p.calificacion_sbs,
  entidades_con_deuda = p.entidades_con_deuda,
  deuda_total_pen = p.deuda_total_pen,
  mayor_deuda = p.mayor_deuda,
  dias_mayor_mora = p.dias_mayor_mora,
  resultado_json = jsonb_build_object(
    'calificacion_sbs', p.calificacion_sbs,
    'entidades_con_deuda', p.entidades_con_deuda,
    'deuda_total_pen', p.deuda_total_pen,
    'mayor_deuda', p.mayor_deuda,
    'dias_mayor_mora', p.dias_mayor_mora,
    'origen', 'perfil_buro_cliente'
  )
from public.perfil_buro_cliente p
where cb.dni_consultado = p.numero_documento
  and (
    cb.resultado_json ->> 'origen' in ('ultimo_digito', 'mock_dni', 'demo_caso')
    or cb.resultado_json is null
  );
