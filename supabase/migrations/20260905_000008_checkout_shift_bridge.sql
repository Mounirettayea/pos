-- Bridge the Flutter checkout payload to the production checkout function.
alter table if exists public.sales add column if not exists shift_id uuid references public.cash_register_shifts(id) on delete set null;
create index if not exists sales_shift_idx on public.sales(shift_id);

create or replace function public.pos_checkout(
  p_subtotal numeric,
  p_discount numeric,
  p_total numeric,
  p_payment_method text,
  p_items jsonb,
  p_customer_id uuid default null,
  p_shift_id uuid default null,
  p_amount_received numeric default 0
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
  v_change numeric := 0;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_discount is null or p_discount < 0 then raise exception 'Invalid discount'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'Cart is empty'; end if;
  if p_shift_id is not null and not exists (select 1 from public.cash_register_shifts where id=p_shift_id and user_id=v_uid and status='open') then raise exception 'Cash shift is not open'; end if;
  if p_payment_method = 'cash' and coalesce(p_amount_received,0) < p_total then raise exception 'Insufficient cash'; end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := coalesce((v_item->>'quantity')::integer, (v_item->>'qty')::integer);
    if v_qty is null or v_qty <= 0 then raise exception 'Invalid quantity'; end if;
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and user_id=v_uid for update;
    if not found then raise exception 'Product not found'; end if;
    if v_product.stock < v_qty then raise exception 'Insufficient stock for %', v_product.name; end if;
    v_sell := v_product.sell_price; v_buy := v_product.buy_price; v_line := v_sell*v_qty;
    v_subtotal := v_subtotal + v_line;
    v_profit := v_profit + ((v_sell-v_buy)*v_qty);
  end loop;

  if p_discount > v_subtotal then raise exception 'Discount exceeds subtotal'; end if;
  if round(p_total,2) <> round(v_subtotal-p_discount,2) then raise exception 'Invalid total'; end if;
  if p_payment_method = 'cash' then v_change := round(coalesce(p_amount_received,0)-p_total,2); end if;

  insert into public.sales(user_id,subtotal,discount,total,profit,payment_method,customer_id,shift_id,amount_received,change_amount)
  values(v_uid,v_subtotal,p_discount,v_subtotal-p_discount,v_profit,coalesce(nullif(p_payment_method,''),'cash'),p_customer_id,p_shift_id,coalesce(p_amount_received,p_total),v_change)
  returning id into v_sale_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := coalesce((v_item->>'quantity')::integer, (v_item->>'qty')::integer);
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and user_id=v_uid for update;
    v_sell := v_product.sell_price; v_buy := v_product.buy_price; v_line := v_sell*v_qty;
    insert into public.sale_items(sale_id,product_id,quantity,unit_buy_price,unit_sell_price,line_total,line_profit)
    values(v_sale_id,v_product.id,v_qty,v_buy,v_sell,v_line,(v_sell-v_buy)*v_qty);
    update public.products set stock=stock-v_qty where id=v_product.id and user_id=v_uid;
    insert into public.inventory_movements(user_id,product_id,quantity_change,reason,sale_id)
    values(v_uid,v_product.id,-v_qty,'sale',v_sale_id);
  end loop;

  insert into public.audit_logs(user_id,action,entity_type,entity_id,details)
  values(v_uid,'create','sale',v_sale_id,jsonb_build_object('total',v_subtotal-p_discount,'payment_method',coalesce(nullif(p_payment_method,''),'cash'),'shift_id',p_shift_id));
  return v_sale_id;
end; $$;
revoke all on function public.pos_checkout(numeric,numeric,numeric,text,jsonb,uuid,numeric,numeric) from public;
grant execute on function public.pos_checkout(numeric,numeric,numeric,text,jsonb,uuid,uuid,numeric) to authenticated;
