-- Maison Al Teeb POS - initial cloud schema
create extension if not exists pgcrypto;

create table if not exists public.mat_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  name_fr text,
  name_en text,
  category text not null default 'other',
  gender text not null default 'unisex',
  size text not null,
  sku text,
  barcode text,
  buy_price numeric(12,2) not null default 0 check (buy_price >= 0),
  sell_price numeric(12,2) not null default 0 check (sell_price >= 0),
  stock integer not null default 0 check (stock >= 0),
  min_stock integer not null default 2 check (min_stock >= 0),
  image_url text,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists mat_products_user_sku_uq
  on public.mat_products(user_id, sku) where sku is not null;

create unique index if not exists mat_products_user_barcode_uq
  on public.mat_products(user_id, barcode) where barcode is not null;

alter table public.mat_products enable row level security;

drop policy if exists "mat_products_select_own" on public.mat_products;
create policy "mat_products_select_own"
  on public.mat_products for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "mat_products_insert_own" on public.mat_products;
create policy "mat_products_insert_own"
  on public.mat_products for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "mat_products_update_own" on public.mat_products;
create policy "mat_products_update_own"
  on public.mat_products for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "mat_products_delete_own" on public.mat_products;
create policy "mat_products_delete_own"
  on public.mat_products for delete
  to authenticated
  using ((select auth.uid()) = user_id);
