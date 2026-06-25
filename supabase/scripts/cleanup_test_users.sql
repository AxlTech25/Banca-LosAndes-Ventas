-- =============================================================================
-- LIMPIEZA — elimina usuarios secundarios; conserva 104592 Juan Perez
-- ⚠️ Solo desarrollo / demo
-- =============================================================================

delete from public.solicitudes_credito
where asesor_id in (
  'b3333333-3333-4333-8333-333333333333',
  'b8888888-8888-4888-8888-888888888801'
);

delete from public.cartera_diaria
where asesor_id in (
  'b3333333-3333-4333-8333-333333333333',
  'b8888888-8888-4888-8888-888888888801'
);

delete from public.asesores_negocio
where codigo_empleado in ('105001', '105002', '201001', '301001', '901001');

delete from auth.users
where email in (
  '105001@losandes.internal',
  '105002@losandes.internal',
  '201001@losandes.internal',
  '301001@losandes.internal',
  '901001@losandes.internal'
);

select codigo_empleado, perfil from public.asesores_negocio order by 1;
