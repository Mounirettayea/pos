-- Production roles for Maison Al Teeb POS
-- Roles: admin, manager, cashier.

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'cashier' check (role in ('admin','manager','cashier')),
  display_name text,
  pin_hash text,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_roles enable row level security;
drop policy if exists user_roles_self_read on public.user_roles;
create policy user_roles_self_read on public.user_roles for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.current_user_role()
returns text language sql stable security definer set search_path=public as $$
  select role from public.user_roles where user_id = auth.uid() and active = true limit 1;
$$;
revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;

create or replace function public.has_role(required_role text)
returns boolean language sql stable security definer set search_path=public as $$
  select case
    when public.current_user_role() = 'admin' then true
    when public.current_user_role() = required_role then true
    else false
  end;
$$;
revoke all on function public.has_role(text) from public;
grant execute on function public.has_role(text) to authenticated;
