-- POS full management: barcode, customers, suppliers, settings and atomic checkout.
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

alter table public.sales add column if not exists customer_id uuid references public.customers(id) on delete set null;

create or replace function public.pos_checkout(p_subtotal numeric,p_discount numeric,p_total numeric,p_payment_method text,p_items jsonb,p_customer_id uuid default null)
returns uuid language plpgsql security invoker set search_path=public as $$
declare v_sale_id uuid; v_item jsonb; v_product public.products%rowtype; v_qty integer; v_sell numeric; v_buy numeric; v_line numeric; v_profit numeric:=0;
begin
 if (select auth.uid()) is null then raise exception 'Authentication required'; end if;
 if p_total < 0 or p_discount < 0 then raise exception 'Invalid totals'; end if;
 insert into public.sales(user_id,subtotal,discount,total,profit,payment_method,customer_id) values(auth.uid(),p_subtotal,p_discount,p_total,0,coalesce(nullif(p_payment_method,''),'cash'),p_customer_id) returning id into v_sale_id;
 for v_item in select * from jsonb_array_elements(p_items) loop
   v_qty := (v_item->>'quantity')::integer;
   select * into v_product from public.products where id=(v_item->>'product_id')::uuid and user_id=auth.uid() for update;
   if not found then raise exception 'Product not found'; end if;
   if v_qty <= 0 or v_product.stock < v_qty then raise exception 'Insufficient stock for %',v_product.name; end if;
   v_sell := v_product.sell_price; v_buy := v_product.buy_price; v_line := v_sell*v_qty; v_profit := v_profit + ((v_sell-v_buy)*v_qty);
   insert into public.sale_items(sale_id,product_id,quantity,unit_buy_price,unit_sell_price,line_total,line_profit) values(v_sale_id,v_product.id,v_qty,v_buy,v_sell,v_line,(v_sell-v_buy)*v_qty);
   update public.products set stock=stock-v_qty where id=v_product.id and user_id=auth.uid();
   insert into public.inventory_movements(user_id,product_id,quantity_change,reason,sale_id) values(auth.uid(),v_product.id,-v_qty,'sale',v_sale_id);
 end loop;
 update public.sales set profit=v_profit where id=v_sale_id;
 return v_sale_id;
end; $$;
revoke all on function public.pos_checkout(numeric,numeric,numeric,text,jsonb,uuid) from public;
grant execute on function public.pos_checkout(numeric,numeric,numeric,text,jsonb,uuid) to authenticated;
