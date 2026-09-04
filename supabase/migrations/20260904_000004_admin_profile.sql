-- Make the existing Supabase Auth account the POS administrator.
-- This does not create a new Auth account and does not change its password.
insert into public.profiles (id, full_name, role)
select id, 'MAISON AL TEEB Admin', 'admin'
from auth.users
where email = 'ferkasni@gmail.com'
on conflict (id) do update
set full_name = excluded.full_name,
    role = 'admin';
