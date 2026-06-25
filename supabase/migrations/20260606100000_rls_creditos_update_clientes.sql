-- RLS adicional para Fase 2: ficha del cliente y actualización de ubicación

create policy "asesor_creditos_select"
  on public.creditos for select
  using (
    asesor_id = public.current_asesor_id()
    or exists (
      select 1 from public.cartera_diaria cd
      where cd.cliente_id = creditos.cliente_id
        and cd.asesor_id = public.current_asesor_id()
    )
  );

create policy "asesor_preaprobados_select"
  on public.creditos_preaprobados for select
  using (asesor_id = public.current_asesor_id());

create policy "asesor_clientes_update_ubicacion"
  on public.clientes for update
  using (
    exists (
      select 1 from public.cartera_diaria cd
      where cd.cliente_id = clientes.id
        and cd.asesor_id = public.current_asesor_id()
    )
  )
  with check (
    exists (
      select 1 from public.cartera_diaria cd
      where cd.cliente_id = clientes.id
        and cd.asesor_id = public.current_asesor_id()
    )
  );
