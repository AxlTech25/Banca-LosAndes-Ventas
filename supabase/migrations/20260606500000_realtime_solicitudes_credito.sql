-- M7: habilitar Realtime en solicitudes_credito (ejecutar en SQL Editor)
-- Tambien activar la tabla en Dashboard → Database → Replication

alter publication supabase_realtime add table public.solicitudes_credito;
