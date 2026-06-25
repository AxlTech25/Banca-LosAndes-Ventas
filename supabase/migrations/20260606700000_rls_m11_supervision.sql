-- M11: RLS supervisor/administrador — lectura por agencia (HU-32, HU-33)

create policy "supervisor_asesores_select"
  on public.asesores_negocio for select
  using (
    public.current_asesor_perfil() in ('supervisor', 'administrador')
    and agencia_id = public.current_agencia_id()
  );

create policy "supervisor_cartera_select"
  on public.cartera_diaria for select
  using (
    public.current_asesor_perfil() in ('supervisor', 'administrador')
    and agencia_id = public.current_agencia_id()
  );

create policy "supervisor_solicitudes_select"
  on public.solicitudes_credito for select
  using (
    public.current_asesor_perfil() in ('supervisor', 'administrador')
    and agencia_id = public.current_agencia_id()
  );

-- Realtime para monitor de cobertura (HU-32)
alter publication supabase_realtime add table public.cartera_diaria;
