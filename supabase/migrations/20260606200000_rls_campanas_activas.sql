create policy "asesor_campanas_select"
  on public.campanas_activas for select
  using (asesor_id = public.current_asesor_id());
