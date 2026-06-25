-- Permite al asesor actualizar sus propios datos (nombres, apellidos)

create policy "asesor_actualiza_su_perfil"
  on public.asesores_negocio for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "asesor_lee_su_agencia"
  on public.agencias for select
  using (id = public.current_agencia_id());
