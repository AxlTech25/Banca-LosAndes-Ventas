-- =============================================================================
-- Cambiar perfil de un asesor sin crear otro usuario Auth
-- Cierra sesión y vuelve a entrar en la app.
-- =============================================================================

-- Ejemplo: Juan 104592 → supervisor (usa 301001 para supervisor dedicado)
-- update public.asesores_negocio set perfil = 'supervisor' where codigo_empleado = '104592';

-- Valores válidos: operador | super_operador | supervisor | administrador

/*
update public.asesores_negocio
set perfil = 'operador'
where codigo_empleado = '105001';
*/

select codigo_empleado, nombres, apellidos, perfil, activo
from public.asesores_negocio
order by codigo_empleado;
