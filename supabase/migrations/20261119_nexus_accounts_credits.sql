-- Nexus platform foundation: individual profiles and monthly usage credits.
-- Run this file once in Supabase SQL Editor before enabling the new Worker version.

create table if not exists public.nexus_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'pro', 'business')),
  credits_remaining integer not null default 100 check (credits_remaining >= 0),
  credits_reset_at timestamptz not null default (date_trunc('month', now()) + interval '1 month'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.nexus_profiles enable row level security;

drop policy if exists "Users can read their own Nexus profile" on public.nexus_profiles;
create policy "Users can read their own Nexus profile"
  on public.nexus_profiles for select
  to authenticated
  using (auth.uid() = id);

create or replace function public.create_nexus_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.nexus_profiles (id, plan, credits_remaining)
  values (new.id, 'free', 100)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_nexus_profile on auth.users;
create trigger on_auth_user_created_nexus_profile
  after insert on auth.users
  for each row execute procedure public.create_nexus_profile();

create or replace function public.consume_nexus_credit(owner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  profile_row public.nexus_profiles%rowtype;
begin
  insert into public.nexus_profiles (id, plan, credits_remaining)
  values (owner_id, 'free', 100)
  on conflict (id) do nothing;

  update public.nexus_profiles
     set credits_remaining = 100,
         credits_reset_at = date_trunc('month', now()) + interval '1 month',
         updated_at = now()
   where id = owner_id and credits_reset_at <= now();

  update public.nexus_profiles
     set credits_remaining = credits_remaining - 1,
         updated_at = now()
   where id = owner_id and credits_remaining > 0
   returning * into profile_row;

  if not found then
    select * into profile_row from public.nexus_profiles where id = owner_id;
    return jsonb_build_object(
      'allowed', false,
      'credits_remaining', coalesce(profile_row.credits_remaining, 0),
      'plan', coalesce(profile_row.plan, 'free')
    );
  end if;

  return jsonb_build_object(
    'allowed', true,
    'credits_remaining', profile_row.credits_remaining,
    'plan', profile_row.plan
  );
end;
$$;

revoke all on function public.consume_nexus_credit(uuid) from public, anon, authenticated;
grant execute on function public.consume_nexus_credit(uuid) to service_role;
grant select on public.nexus_profiles to authenticated, service_role;
