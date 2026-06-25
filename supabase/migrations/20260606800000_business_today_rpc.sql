-- Fecha operativa del negocio (misma que current_date en seeds demo)
create or replace function public.business_today()
returns date
language sql
stable
security definer
set search_path = public
as $$
  select current_date;
$$;

grant execute on function public.business_today() to authenticated, anon;
