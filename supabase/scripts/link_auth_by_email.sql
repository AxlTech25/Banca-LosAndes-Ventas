-- =============================================================================
-- Vincular asesores_negocio con auth.users creados manualmente en el Dashboard
-- Patrón de email en la app: {codigo_empleado}@losandes.internal
-- =============================================================================

update public.asesores_negocio an
set user_id = u.id
from auth.users u
where u.email = an.codigo_empleado || '@losandes.internal'
  and an.user_id is distinct from u.id;

-- Asesores sin usuario Auth
select
  an.codigo_empleado,
  an.nombres,
  an.apellidos,
  an.perfil,
  an.codigo_empleado || '@losandes.internal' as email_esperado
from public.asesores_negocio an
left join auth.users u on u.id = an.user_id
where u.id is null;
