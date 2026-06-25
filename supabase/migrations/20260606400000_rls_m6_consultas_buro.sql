-- M6: consulta buró + notas internas de solicitud

create policy "asesor_buro_select"
  on public.consultas_buro for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_buro_insert"
  on public.consultas_buro for insert
  with check (asesor_id = public.current_asesor_id());

create policy "asesor_notas_select"
  on public.solicitudes_notas_internas for select
  using (
    exists (
      select 1
      from public.solicitudes_credito sc
      where sc.id = solicitud_id
        and sc.asesor_id = public.current_asesor_id()
    )
  );

create policy "asesor_notas_insert"
  on public.solicitudes_notas_internas for insert
  with check (
    asesor_id = public.current_asesor_id()
    and exists (
      select 1
      from public.solicitudes_credito sc
      where sc.id = solicitud_id
        and sc.asesor_id = public.current_asesor_id()
    )
  );
