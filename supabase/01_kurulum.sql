-- Anaokulu Kapı Sistemi: veritabanı kurulumu
-- Supabase > SQL Editor içine yapıştırıp bir kez çalıştırın.

-- 1) Tablolar
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null,
  full_name text not null,
  cls text,
  role text not null default 'teacher' check (role in ('teacher','admin')),
  active boolean not null default true,
  must_change boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.visits (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  parent_name text not null check (char_length(parent_name) between 2 and 80),
  phone text not null check (char_length(phone) between 10 and 20),
  relation text not null check (char_length(relation) <= 40),
  child_name text not null check (char_length(child_name) between 2 and 80),
  purpose text not null check (char_length(purpose) <= 80),
  teacher_id uuid not null references public.profiles(id),
  status text not null default 'new' check (status in ('new','coming','closed')),
  coming_at timestamptz,
  closed_at timestamptz,
  closed_by text
);
create index if not exists visits_created_idx on public.visits (created_at desc);
create index if not exists visits_teacher_idx on public.visits (teacher_id, status);

alter table public.profiles enable row level security;
alter table public.visits enable row level security;

-- 2) Yardımcı: giriş yapan kişi yönetici mi?
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from profiles where id = auth.uid() and role = 'admin' and active);
$$;

-- 3) Güvenlik kuralları
drop policy if exists "profil okuma" on public.profiles;
create policy "profil okuma" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
drop policy if exists "yonetici profil gunceller" on public.profiles;
create policy "yonetici profil gunceller" on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists "kayit okuma" on public.visits;
create policy "kayit okuma" on public.visits for select to authenticated
  using (teacher_id = auth.uid() or public.is_admin());
drop policy if exists "kayit guncelleme" on public.visits;
create policy "kayit guncelleme" on public.visits for update to authenticated
  using (teacher_id = auth.uid() or public.is_admin())
  with check (teacher_id = auth.uid() or public.is_admin());
-- Velilerin tabloya doğrudan erişimi yok; yalnızca aşağıdaki fonksiyonları kullanırlar.

-- 4) Yeni kullanıcı açılınca profil oluştur (rol her zaman öğretmen başlar)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, username, full_name, cls, role, must_change)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'cls',
    'teacher',
    true
  );
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 5) Veli tarafı fonksiyonları (giriş gerektirmez)
create or replace function public.active_teachers()
returns table (id uuid, full_name text, cls text)
language sql stable security definer set search_path = public as $$
  select id, full_name, cls from profiles where role = 'teacher' and active order by full_name;
$$;

create or replace function public.submit_visit(
  p_parent text, p_phone text, p_relation text, p_child text, p_purpose text, p_teacher uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not exists (select 1 from profiles where id = p_teacher and role = 'teacher' and active) then
    raise exception 'Öğretmen bulunamadı';
  end if;
  if (select count(*) from visits where phone = trim(p_phone) and created_at > now() - interval '2 minutes') >= 3 then
    raise exception 'Çok sık gönderim yapıldı. Lütfen biraz bekleyin.';
  end if;
  insert into visits (parent_name, phone, relation, child_name, purpose, teacher_id)
  values (trim(p_parent), trim(p_phone), p_relation, trim(p_child), p_purpose, p_teacher)
  returning id into v_id;
  return v_id;
end $$;

create or replace function public.visit_status(p_id uuid)
returns table (status text, teacher_name text)
language sql stable security definer set search_path = public as $$
  select v.status, p.full_name from visits v join profiles p on p.id = v.teacher_id where v.id = p_id;
$$;

-- 6) Öğretmen ilk şifresini değiştirince işaret kaldırılır
create or replace function public.password_changed() returns void
language sql security definer set search_path = public as $$
  update profiles set must_change = false where id = auth.uid();
$$;
revoke execute on function public.password_changed() from anon, public;
grant execute on function public.password_changed() to authenticated;

-- 7) Öğretmen paneli için canlı güncelleme
do $$ begin
  alter publication supabase_realtime add table public.visits;
exception when duplicate_object then null; end $$;
