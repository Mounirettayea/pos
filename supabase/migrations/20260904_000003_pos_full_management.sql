-- POS full management: barcode, customers, suppliers, settings.
alter table public.products add column if not exists barcode text;
create unique index if not exists products_user_barcode_uq on public.products(user_id, barcode) where barcode is not null;

create table if not exists public.customers (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, name text not null, phone text, email text, address text, notes text, created_at timestamptz not null default now());
create index if not exists customers_user_idx on public.customers(user_id);
alter table public.customers enable row level security;
drop policy if exists customers_own_select on public.customers; create policy customers_own_select on public.customers for select to authenticated using (user_id=(select auth.uid()));
drop policy if exists customers_own_insert on public.customers; create policy customers_own_insert on public.customers for insert to authenticated with check (user_id=(select auth.uid()));
drop policy if exists customers_own_update on public.customers; create policy customers_own_update on public.customers for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
drop policy if exists customers_own_delete on public.customers; create policy customers_own_delete on public.customers for delete to authenticated using (user_id=(select auth.uid()));

create table if not exists public.suppliers (id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade, name text not null, phone text, email text, address text, notes text, created_at timestamptz not null default now());
create index if not exists suppliers_user_idx on public.suppliers(user_id);
alter table public.suppliers enable row level security;
drop policy if exists suppliers_own_select on public.suppliers; create policy suppliers_own_select on public.suppliers for select to authenticated using (user_id=(select auth.uid()));
drop policy if exists suppliers_own_insert on public.suppliers; create policy suppliers_own_insert on public.suppliers for insert to authenticated with check (user_id=(select auth.uid()));
drop policy if exists suppliers_own_update on public.suppliers; create policy suppliers_own_update on public.suppliers for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
drop policy if exists suppliers_own_delete on public.suppliers; create policy suppliers_own_delete on public.suppliers for delete to authenticated using (user_id=(select auth.uid()));

create table if not exists public.app_settings (user_id uuid primary key references auth.users(id) on delete cascade, store_name text not null default 'MAISON AL TEEB', phone text, address text, currency text not null default 'MAD', language text not null default 'ar', low_stock_threshold integer not null default 2, receipt_footer text, updated_at timestamptz not null default now());
alter table public.app_settings enable row level security;
drop policy if exists app_settings_own_select on public.app_settings; create policy app_settings_own_select on public.app_settings for select to authenticated using (user_id=(select auth.uid()));
drop policy if exists app_settings_own_insert on public.app_settings; create policy app_settings_own_insert on public.app_settings for insert to authenticated with check (user_id=(select auth.uid()));
drop policy if exists app_settings_own_update on public.app_settings; create policy app_settings_own_update on public.app_settings for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));

create index if not exists sales_user_created_idx on public.sales(user_id, created_at desc);
create index if not exists inventory_user_created_idx on public.inventory_movements(user_id, created_at desc);
create index if not exists expenses_user_date_idx on public.expenses(user_id, expense_date desc);
