-- Maison Al Teeb POS V1 production foundation
-- Adds cash shifts, purchases, returns, audit trail, offline sync queue,
-- and makes checkout totals server-authoritative.

create table if not exists public.cash_register_shifts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  opened_by uuid not null default auth.uid() references auth.users(id),
  opened_at timestamptz not null default now(),
  opening_cash numeric(12,2) not null default 0 check (opening_cash >= 0),
  closed_at timestamptz,
  closed_by uuid references auth.users(id),
  expected_cash numeric(12,2),
  actual_cash numeric(12,2),
  difference numeric(12,2),
  status text not null default 'open' check (status in ('open','closed')),
  notes text
);
create unique index if not exists cash_one_open_shift_per_user on public.cash_register_shifts(user_id) where status = 'open';
create index if not exists cash_shift_user_opened_idx on public.cash_register_shifts(user_id, opened_at desc);
alter table public.cash_register_shifts enable row level security;
drop policy if exists cash_shift_own on public.cash_register_shifts;
create policy cash_shift_own on public.cash_register_shifts for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table if not exists public.purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  supplier_id uuid references public.suppliers(id) on delete set null,
  reference text,
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  discount numeric(12,2) not null default 0 check (discount >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  status text not null default 'received' check (status in ('draft','received','cancelled')),
  purchase_date timestamptz not null default now(),
  notes text
);
create table if not exists public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  unit_cost numeric(12,2) not null check (unit_cost >= 0),
  line_total numeric(12,2) not null default 0 check (line_total >= 0)
);
create index if not exists purchases_user_date_idx on public.purchases(user_id, purchase_date desc);
create index if not exists purchase_items_purchase_idx on public.purchase_items(purchase_id);
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
drop policy if exists purchases_own on public.purchases;
create policy purchases_own on public.purchases for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists purchase_items_own on public.purchase_items;
create policy purchase_items_own on public.purchase_items for all to authenticated using (exists (select 1 from public.purchases p where p.id = purchase_id and p.user_id = (select auth.uid()))) with check (exists (select 1 from public.purchases p where p.id = purchase_id and p.user_id = (select auth.uid())));

create table if not exists public.returns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  sale_id uuid references public.sales(id) on delete set null,
  refund_amount numeric(12,2) not null default 0 check (refund_amount >= 0),
  reason text,
  payment_method text not null default 'cash',
  created_at timestamptz not null default now()
);
create table if not exists public.return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.returns(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) not null default 0 check (line_total >= 0)
);
create index if not exists returns_user_date_idx on public.returns(user_id, created_at desc);
create index if not exists return_items_return_idx on public.return_items(return_id);
alter table public.returns enable row level security;
alter table public.return_items enable row level security;
drop policy if exists returns_own on public.returns;
create policy returns_own on public.returns for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists return_items_own on public.return_items;
create policy return_items_own on public.return_items for all to authenticated using (exists (select 1 from public.returns r where r.id = return_id and r.user_id = (select auth.uid()))) with check (exists (select 1 from public.returns r where r.id = return_id and r.user_id = (select auth.uid())));

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_logs_user_date_idx on public.audit_logs(user_id, created_at desc);
alter table public.audit_logs enable row level security;
drop policy if exists audit_logs_own on public.audit_logs;
create policy audit_logs_own on public.audit_logs for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create table if not exists public.sync_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  operation text not null check (operation in ('create','update','delete','sale','stock_movement','return','purchase','expense')),
  entity_type text not null,
  entity_id uuid,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'pending' check (status in ('pending','syncing','synced','failed')),
  attempts integer not null default 0 check (attempts >= 0),
  last_error text,
  created_at timestamptz not null default now(),
  synced_at timestamptz
);
create index if not exists sync_queue_pending_idx on public.sync_queue(user_id, status, created_at);
alter table public.sync_queue enable row level security;
drop policy if exists sync_queue_own on public.sync_queue;
create policy sync_queue_own on public.sync_queue for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Server-authoritative checkout: totals are recomputed from DB prices and stock.
create or replace function public.pos_checkout(
  p_subtotal numeric,
  p_discount numeric,
  p_total numeric,
  p_payment_method text,
  p_items jsonb,
  p_customer_id uuid default null
)
returns uuid language plpgsql security invoker set search_path=public as $$
declare
  v_sale_id uuid;
  v_item jsonb;
  v_product public.products%rowtype;
  v_qty integer;
  v_sell numeric;
  v_buy numeric;
  v_line numeric;
  v_subtotal numeric := 0;
  v_profit numeric := 0;
  v_customer_user uuid;
begin
  if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
  if p_discount is null or p_discount < 0 then raise exception 'Invalid discount'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Cart is empty'; end if;
  if p_customer_id is not null then
    select user_id into v_customer_user from public.customers where id = p_customer_id;
    if v_customer_user is distinct from auth.uid() then raise exception 'Customer not found'; end if;
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := coalesce((v_item->>'quantity')::integer, (v_item->>'qty')::integer);
    if v_qty is null or v_qty <= 0 then raise exception 'Invalid quantity'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and user_id=auth.uid() for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock < v_qty then raise exception 'Insufficient stock for %', v_product.name; end if;
    v_sell := v_product.sell_price; v_buy := v_product.buy_price; v_line := v_sell*v_qty;
    v_subtotal := v_subtotal + v_line;
    v_profit := v_profit + ((v_sell-v_buy)*v_qty);
  end loop;

  if p_discount > v_subtotal then raise exception 'Discount exceeds subtotal'; end if;
  if round(p_total,2) <> round(v_subtotal-p_discount,2) then raise exception 'Invalid total'; end if;

  insert into public.sales(user_id,subtotal,discount,total,profit,payment_method,customer_id)
  values(auth.uid(),v_subtotal,p_discount,v_subtotal-p_discount,v_profit,coalesce(nullif(p_payment_method,''),'cash'),p_customer_id)
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := coalesce((v_item->>'quantity')::integer, (v_item->>'qty')::integer);
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and user_id=auth.uid() for update;
    v_sell := v_product.sell_price; v_buy := v_product.buy_price; v_line := v_sell*v_qty;
    insert into public.sale_items(sale_id,product_id,quantity,unit_buy_price,unit_sell_price,line_total,line_profit)
    values(v_sale_id,v_product.id,v_qty,v_buy,v_sell,v_line,(v_sell-v_buy)*v_qty);
    update public.products set stock=stock-v_qty where id=v_product.id and user_id=auth.uid();
    insert into public.inventory_movements(user_id,product_id,quantity_change,reason,sale_id)
    values(auth.uid(),v_product.id,-v_qty,'sale',v_sale_id);
  end loop;

  insert into public.audit_logs(user_id,action,entity_type,entity_id,details)
  values(auth.uid(),'create','sale',v_sale_id,jsonb_build_object('total',v_subtotal-p_discount,'payment_method',coalesce(nullif(p_payment_method,''),'cash')));
  return v_sale_id;
end; $$;
revoke all on function public.pos_checkout(numeric,numeric,numeric,text,jsonb,uuid) from public;
grant execute on function public.pos_checkout(numeric,numeric,numeric,text,jsonb,uuid) to authenticated;
