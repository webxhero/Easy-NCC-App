-- Easy NCC Phase 1 schema
-- Run this entire file in Supabase Dashboard > SQL Editor.
-- This script is intended for a new Easy NCC Supabase project.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Profiles and roles
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Member',
  cadet_number text unique,
  rank text,
  unit_name text,
  avatar_url text,
  role text not null default 'member' check (role in ('admin', 'supervisor', 'member')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create assignments early because helper functions below query this table.
create table if not exists public.supervisor_assignments (
  id uuid primary key default gen_random_uuid(),
  supervisor_id uuid not null references public.profiles(id) on delete cascade,
  cadet_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (supervisor_id, cadet_id),
  check (supervisor_id <> cadet_id)
);

create or replace function public.current_user_role()
returns text
language sql stable security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'admin', false);
$$;

create or replace function public.is_supervisor()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() = 'supervisor', false);
$$;

create or replace function public.is_assigned_cadet(target_cadet uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.supervisor_assignments sa
    where sa.supervisor_id = auth.uid() and sa.cadet_id = target_cadet
  );
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(new.email, 'member'), '@', 1)),
    'member'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.guard_profile_role_change()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if old.role is distinct from new.role and auth.uid() is not null and not public.is_admin() then
    raise exception 'Only an administrator can change account roles.';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_role on public.profiles;
create trigger protect_profile_role
before update on public.profiles
for each row execute procedure public.guard_profile_role_change();

-- ---------------------------------------------------------------------------
-- Activity / To-do events and notes
-- ---------------------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_by_name text not null default 'Member',
  title text not null check (length(trim(title)) > 0),
  event_date date not null,
  completed boolean not null default false,
  completed_at timestamptz,
  visibility text not null default 'personal' check (visibility in ('personal', 'central')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.event_notes (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  created_by_name text not null default 'Member',
  note text not null check (length(trim(note)) > 0),
  created_at timestamptz not null default now()
);

create or replace function public.set_created_by_name()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare actor_name text;
begin
  select display_name into actor_name from public.profiles where id = auth.uid();
  if actor_name is not null then new.created_by_name := actor_name; end if;
  return new;
end;
$$;

drop trigger if exists events_set_created_by_name on public.events;
create trigger events_set_created_by_name before insert on public.events
for each row execute procedure public.set_created_by_name();

drop trigger if exists event_notes_set_created_by_name on public.event_notes;
create trigger event_notes_set_created_by_name before insert on public.event_notes
for each row execute procedure public.set_created_by_name();

-- Keep the attribution label immutable after insert so users cannot spoof who added a record.
create or replace function public.preserve_record_attribution()
returns trigger language plpgsql
as $$
begin
  if tg_table_name = 'events' then
    new.owner_id := old.owner_id;
  else
    new.created_by := old.created_by;
  end if;
  new.created_by_name := old.created_by_name;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Cadet measurements
-- ---------------------------------------------------------------------------
create table if not exists public.measurements (
  id uuid primary key default gen_random_uuid(),
  cadet_user_id uuid references public.profiles(id) on delete set null,
  created_by uuid not null references public.profiles(id) on delete cascade,
  cadet_name text not null,
  cadet_number text not null,
  shirt_length text not null default '',
  shirt_body text not null default '',
  shirt_cuff text not null default '',
  shirt_hand text not null default '',
  shirt_pet text not null default '',
  shirt_hip text not null default '',
  shirt_collar text not null default '',
  pant_length text not null default '',
  pant_run text not null default '',
  pant_high text not null default '',
  pant_waist text not null default '',
  pant_muri text not null default '',
  pant_hip text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Notices and announcements
-- ---------------------------------------------------------------------------
create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_by_name text not null default 'Member',
  title text not null check (length(trim(title)) > 0),
  body text not null check (length(trim(body)) > 0),
  category text not null default 'General',
  priority text not null default 'normal' check (priority in ('normal', 'important')),
  is_published boolean not null default true,
  published_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists notices_set_created_by_name on public.notices;
create trigger notices_set_created_by_name before insert on public.notices
for each row execute procedure public.set_created_by_name();

-- ---------------------------------------------------------------------------
-- Training records
-- ---------------------------------------------------------------------------
create table if not exists public.training_records (
  id uuid primary key default gen_random_uuid(),
  cadet_user_id uuid not null references public.profiles(id) on delete cascade,
  cadet_name text not null default 'Cadet',
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_by_name text not null default 'Member',
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  training_date date not null,
  status text not null default 'in_progress' check (status in ('planned', 'in_progress', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists training_set_created_by_name on public.training_records;
create trigger training_set_created_by_name before insert on public.training_records
for each row execute procedure public.set_created_by_name();

create or replace function public.set_training_cadet_name()
returns trigger language plpgsql security definer set search_path = public
as $$
declare cadet_display_name text;
begin
  select display_name into cadet_display_name from public.profiles where id = new.cadet_user_id;
  if cadet_display_name is not null then new.cadet_name := cadet_display_name; end if;
  return new;
end;
$$;
drop trigger if exists training_set_cadet_name on public.training_records;
create trigger training_set_cadet_name before insert or update of cadet_user_id on public.training_records
for each row execute procedure public.set_training_cadet_name();

-- Updated timestamp helper
create or replace function public.set_updated_at()
returns trigger language plpgsql
as $$ begin new.updated_at = now(); return new; end; $$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
drop trigger if exists events_updated_at on public.events;
create trigger events_updated_at before update on public.events for each row execute procedure public.set_updated_at();
drop trigger if exists events_preserve_attribution on public.events;
create trigger events_preserve_attribution before update on public.events for each row execute procedure public.preserve_record_attribution();
drop trigger if exists measurements_updated_at on public.measurements;
create trigger measurements_updated_at before update on public.measurements for each row execute procedure public.set_updated_at();
drop trigger if exists notices_updated_at on public.notices;
create trigger notices_updated_at before update on public.notices for each row execute procedure public.set_updated_at();
drop trigger if exists notices_preserve_attribution on public.notices;
create trigger notices_preserve_attribution before update on public.notices for each row execute procedure public.preserve_record_attribution();
drop trigger if exists training_updated_at on public.training_records;
create trigger training_updated_at before update on public.training_records for each row execute procedure public.set_updated_at();
drop trigger if exists training_preserve_attribution on public.training_records;
create trigger training_preserve_attribution before update on public.training_records for each row execute procedure public.preserve_record_attribution();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.supervisor_assignments enable row level security;
alter table public.events enable row level security;
alter table public.event_notes enable row level security;
alter table public.measurements enable row level security;
alter table public.notices enable row level security;
alter table public.training_records enable row level security;

-- Profiles: the directory is visible only to signed-in members.
drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated" on public.profiles
for select to authenticated using (true);
drop policy if exists "profiles_update_self_or_admin" on public.profiles;
create policy "profiles_update_self_or_admin" on public.profiles
for update to authenticated using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

-- Assignment rows: only admins manage; related supervisor/cadet can read their own assignment.
drop policy if exists "assignments_read_related" on public.supervisor_assignments;
create policy "assignments_read_related" on public.supervisor_assignments
for select to authenticated using (supervisor_id = auth.uid() or cadet_id = auth.uid() or public.is_admin());
drop policy if exists "assignments_admin_insert" on public.supervisor_assignments;
create policy "assignments_admin_insert" on public.supervisor_assignments
for insert to authenticated with check (public.is_admin());
drop policy if exists "assignments_admin_delete" on public.supervisor_assignments;
create policy "assignments_admin_delete" on public.supervisor_assignments
for delete to authenticated using (public.is_admin());

-- Events: central events are readable by everyone, including anonymous visitors.
drop policy if exists "events_read_central_or_owner" on public.events;
create policy "events_read_central_or_owner" on public.events
for select to anon, authenticated
using (visibility = 'central' or owner_id = auth.uid() or public.is_admin());
drop policy if exists "events_insert_authenticated" on public.events;
create policy "events_insert_authenticated" on public.events
for insert to authenticated with check (owner_id = auth.uid());
drop policy if exists "events_update_owner_or_admin" on public.events;
create policy "events_update_owner_or_admin" on public.events
for update to authenticated using (owner_id = auth.uid() or public.is_admin())
with check (owner_id = auth.uid() or public.is_admin());
drop policy if exists "events_delete_owner_or_admin" on public.events;
create policy "events_delete_owner_or_admin" on public.events
for delete to authenticated using (owner_id = auth.uid() or public.is_admin());

-- Notes inherit the visibility of their parent event. Only note owner/admin can edit/delete.
drop policy if exists "event_notes_read_parent_access" on public.event_notes;
create policy "event_notes_read_parent_access" on public.event_notes
for select to anon, authenticated using (
  exists (select 1 from public.events e where e.id = event_id
    and (e.visibility = 'central' or e.owner_id = auth.uid() or public.is_admin()))
);
drop policy if exists "event_notes_insert_parent_access" on public.event_notes;
create policy "event_notes_insert_parent_access" on public.event_notes
for insert to authenticated with check (
  owner_id = auth.uid() and exists (select 1 from public.events e where e.id = event_id
    and (e.visibility = 'central' or e.owner_id = auth.uid() or public.is_admin()))
);
drop policy if exists "event_notes_delete_owner_or_admin" on public.event_notes;
create policy "event_notes_delete_owner_or_admin" on public.event_notes
for delete to authenticated using (owner_id = auth.uid() or public.is_admin());

-- Measurements: member can read own linked record; creator/admin/assigned supervisor can read.
drop policy if exists "measurements_read_authorized" on public.measurements;
create policy "measurements_read_authorized" on public.measurements
for select to authenticated using (
  cadet_user_id = auth.uid() or created_by = auth.uid() or public.is_admin()
  or (cadet_user_id is not null and public.is_assigned_cadet(cadet_user_id))
);
drop policy if exists "measurements_insert_admin_or_assigned_supervisor" on public.measurements;
create policy "measurements_insert_admin_or_assigned_supervisor" on public.measurements
for insert to authenticated with check (
  created_by = auth.uid() and (
    public.is_admin() or (public.is_supervisor() and cadet_user_id is not null and public.is_assigned_cadet(cadet_user_id))
  )
);
drop policy if exists "measurements_update_admin_or_assigned_supervisor" on public.measurements;
create policy "measurements_update_admin_or_assigned_supervisor" on public.measurements
for update to authenticated using (
  public.is_admin() or (public.is_supervisor() and cadet_user_id is not null and public.is_assigned_cadet(cadet_user_id))
) with check (
  public.is_admin() or (public.is_supervisor() and cadet_user_id is not null and public.is_assigned_cadet(cadet_user_id))
);
drop policy if exists "measurements_delete_admin_or_assigned_supervisor" on public.measurements;
create policy "measurements_delete_admin_or_assigned_supervisor" on public.measurements
for delete to authenticated using (
  public.is_admin() or (public.is_supervisor() and cadet_user_id is not null and public.is_assigned_cadet(cadet_user_id))
);

-- Notices: members read published notices; admins/supervisors publish; creator/admin manages.
drop policy if exists "notices_read_published_or_manager" on public.notices;
create policy "notices_read_published_or_manager" on public.notices
for select to authenticated using (is_published or created_by = auth.uid() or public.is_admin() or public.is_supervisor());
drop policy if exists "notices_insert_admin_supervisor" on public.notices;
create policy "notices_insert_admin_supervisor" on public.notices
for insert to authenticated with check (created_by = auth.uid() and (public.is_admin() or public.is_supervisor()));
drop policy if exists "notices_update_creator_or_admin" on public.notices;
create policy "notices_update_creator_or_admin" on public.notices
for update to authenticated using (created_by = auth.uid() or public.is_admin())
with check (created_by = auth.uid() or public.is_admin());
drop policy if exists "notices_delete_creator_or_admin" on public.notices;
create policy "notices_delete_creator_or_admin" on public.notices
for delete to authenticated using (created_by = auth.uid() or public.is_admin());

-- Training: member reads own progress; assigned supervisor/admin manage it.
drop policy if exists "training_read_authorized" on public.training_records;
create policy "training_read_authorized" on public.training_records
for select to authenticated using (
  cadet_user_id = auth.uid() or created_by = auth.uid() or public.is_admin()
  or public.is_assigned_cadet(cadet_user_id)
);
drop policy if exists "training_insert_admin_or_assigned_supervisor" on public.training_records;
create policy "training_insert_admin_or_assigned_supervisor" on public.training_records
for insert to authenticated with check (
  created_by = auth.uid() and (public.is_admin() or (public.is_supervisor() and public.is_assigned_cadet(cadet_user_id)))
);
drop policy if exists "training_update_admin_or_assigned_supervisor" on public.training_records;
create policy "training_update_admin_or_assigned_supervisor" on public.training_records
for update to authenticated using (
  public.is_admin() or (public.is_supervisor() and public.is_assigned_cadet(cadet_user_id))
) with check (
  public.is_admin() or (public.is_supervisor() and public.is_assigned_cadet(cadet_user_id))
);
drop policy if exists "training_delete_admin_or_assigned_supervisor" on public.training_records;
create policy "training_delete_admin_or_assigned_supervisor" on public.training_records
for delete to authenticated using (
  public.is_admin() or (public.is_supervisor() and public.is_assigned_cadet(cadet_user_id))
);

-- Helpful indexes
create index if not exists events_owner_date_idx on public.events(owner_id, event_date);
create index if not exists events_visibility_date_idx on public.events(visibility, event_date);
create index if not exists event_notes_event_idx on public.event_notes(event_id, created_at);
create index if not exists measurements_cadet_user_idx on public.measurements(cadet_user_id);
create index if not exists training_cadet_date_idx on public.training_records(cadet_user_id, training_date);
create index if not exists notices_published_date_idx on public.notices(is_published, published_at desc);

-- Grant the standard table operations used by the Flutter client. RLS still applies.
grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.supervisor_assignments to authenticated;
grant select, insert, update, delete on public.events to authenticated;
grant select on public.events to anon;
grant select, insert, delete on public.event_notes to authenticated;
grant select on public.event_notes to anon;
grant select, insert, update, delete on public.measurements to authenticated;
grant select, insert, update, delete on public.notices to authenticated;
grant select, insert, update, delete on public.training_records to authenticated;

-- IMPORTANT AFTER RUNNING THIS SCRIPT:
-- 1) Create the first account in Easy NCC.
-- 2) In Supabase SQL Editor, promote that account to admin using its Auth user UUID:
--    update public.profiles set role = 'admin' where id = 'YOUR-AUTH-USER-UUID';
-- 3) Use the Admin account to promote supervisors and assign cadets.
