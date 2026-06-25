-- M8: cobranza en campo

create policy "asesor_cartera_vencida_select"
  on public.cartera_vencida for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_cartera_vencida_update"
  on public.cartera_vencida for update
  using (asesor_id = public.current_asesor_id())
  with check (asesor_id = public.current_asesor_id());

create policy "asesor_acciones_cobranza_select"
  on public.acciones_cobranza for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_acciones_cobranza_insert"
  on public.acciones_cobranza for insert
  with check (asesor_id = public.current_asesor_id());
