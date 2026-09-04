-- Maison Al Teeb POS - sales and stock movements
create table if not exists public.mat_sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  invoice_number text not null,
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  payment_method text not null default 'cash',
  created_at timestamptz not null default now()
);

create table if not exists public.mat_sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.mat_sales(id) on delete cascade,
  product_id uuid not null references public.mat_products(id),
  product_name text not null,
  barcode text,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  unit_cost numeric(12,2) not null default 0 check (unit_cost >= 0)
);

create table if not exists public.mat_stock_movements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  product_id uuid not null references public.mat_products(id),
  movement_type text not null check (movement_type in ('sale','purchase','adjustment','return')),
  quantity integer not null,
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);

alter table public.mat_sales enable row level security;
alter table public.mat_sale_items enable row level security;
alter table public.mat_stock_movements enable row level security;

drop policy if exists "mat_sales_own" on public.mat_sales;
create policy "mat_sales_own" on public.mat_sales
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "mat_sale_items_own" on public.mat_sale_items;
create policy "mat_sale_items_own" on public.mat_sale_items
  for all to authenticated
  using (
    exists (
      select 1 from public.mat_sales s
      where s.id = sale_id and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.mat_sales s
      where s.id = sale_id and s.user_id = (select auth.uid())
    )
  );

drop policy if exists "mat_stock_movements_own" on public.mat_stock_movements;
create policy "mat_stock_movements_own" on public.mat_stock_movements
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create index if not exists mat_sales_user_created_idx
  on public.mat_sales(user_id, created_at desc);

create index if not exists mat_sale_items_sale_idx
  on public.mat_sale_items(sale_id);

create index if not exists mat_stock_movements_product_idx
  on public.mat_stock_movements(product_id, created_at desc);


-- Atomic stock decrement used by checkout.
create or replace function public.mat_decrement_stock(
  p_product_id uuid,
  p_quantity integer
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  current_stock integer;
begin
  if p_quantity <= 0 then
    raise exception 'Quantity must be positive';
  end if;

  select stock into current_stock
  from public.mat_products
  where id = p_product_id
    and user_id = (select auth.uid())
  for update;

  if current_stock is null then
    raise exception 'Product not found';
  end if;

  if current_stock < p_quantity then
    raise exception 'Insufficient stock';
  end if;

  update public.mat_products
  set stock = stock - p_quantity,
      updated_at = now()
  where id = p_product_id
    and user_id = (select auth.uid());

  insert into public.mat_stock_movements(
    user_id, product_id, movement_type, quantity, note
  )
  values (
    (select auth.uid()), p_product_id, 'sale', -p_quantity, 'POS sale'
  );
end;
$$;

revoke all on function public.mat_decrement_stock(uuid, integer) from public;
grant execute on function public.mat_decrement_stock(uuid, integer) to authenticated;
