-- Maison Al Teeb POS: controlled inventory adjustments.
-- All stock corrections go through one server-side function so the stock and movement log stay consistent.

create or replace function public.adjust_product_stock(
  p_product_id uuid,
  p_quantity_change integer,
  p_reason text default 'adjustment',
  p_notes text default null
)
returns integer
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_product public.products%rowtype;
  v_new_stock integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Authentication required';
  end if;
  if p_quantity_change = 0 then
    raise exception 'Quantity change cannot be zero';
  end if;
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Reason is required';
  end if;

  select * into v_product
  from public.products
  where id = p_product_id and user_id = auth.uid()
  for update;

  if not found then raise exception 'Product not found'; end if;

  v_new_stock := v_product.stock + p_quantity_change;
  if v_new_stock < 0 then raise exception 'Stock cannot be negative'; end if;

  update public.products
  set stock = v_new_stock
  where id = p_product_id and user_id = auth.uid();

  insert into public.inventory_movements(user_id, product_id, quantity_change, reason)
  values (
    auth.uid(),
    p_product_id,
    p_quantity_change,
    case when p_notes is null then p_reason else p_reason || ': ' || p_notes end
  );

  insert into public.audit_logs(user_id, action, entity_type, entity_id, details)
  values (
    auth.uid(), 'adjust_stock', 'product', p_product_id,
    jsonb_build_object(
      'quantity_change', p_quantity_change,
      'old_stock', v_product.stock,
      'new_stock', v_new_stock,
      'reason', p_reason,
      'notes', p_notes
    )
  );

  return v_new_stock;
end;
$$;

revoke all on function public.adjust_product_stock(uuid, integer, text, text) from public;
grant execute on function public.adjust_product_stock(uuid, integer, text, text) to authenticated;

create index if not exists products_user_stock_idx
  on public.products(user_id, stock);

create index if not exists products_user_category_idx
  on public.products(user_id, category);
