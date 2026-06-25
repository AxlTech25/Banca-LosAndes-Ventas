-- M5: prospectos nuevos + documentos de solicitud

create policy "asesor_clientes_insert"
  on public.clientes for insert
  with check (
    exists (
      select 1
      from public.asesores_negocio an
      where an.user_id = auth.uid()
        and an.activo = true
    )
  );

create policy "asesor_clientes_select_activo"
  on public.clientes for select
  using (
    exists (
      select 1
      from public.asesores_negocio an
      where an.user_id = auth.uid()
        and an.activo = true
    )
  );

create policy "asesor_documentos_select"
  on public.solicitudes_documentos for select
  using (
    exists (
      select 1
      from public.solicitudes_credito sc
      where sc.id = solicitud_id
        and sc.asesor_id = public.current_asesor_id()
    )
  );

create policy "asesor_documentos_insert"
  on public.solicitudes_documentos for insert
  with check (
    exists (
      select 1
      from public.solicitudes_credito sc
      where sc.id = solicitud_id
        and sc.asesor_id = public.current_asesor_id()
    )
  );
