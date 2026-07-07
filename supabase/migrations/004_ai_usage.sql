-- AI proxy per-user daily usage quota.
-- Backs the `ai-proxy` Edge Function so a shared Gemini key can't be abused
-- by a single user, and so the key never has to live in the client.

create table if not exists ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  day date not null default current_date,
  count int not null default 0,
  primary key (user_id, day)
);

alter table ai_usage enable row level security;

-- Users may read their own usage; writes happen only via the SECURITY DEFINER
-- function below (no direct insert/update policy is intentional).
drop policy if exists "users read own ai_usage" on ai_usage;
create policy "users read own ai_usage"
  on ai_usage for select
  using (auth.uid() = user_id);

-- Atomically increment today's counter for the calling user and report whether
-- they are still within the daily limit. SECURITY DEFINER lets it write past RLS;
-- auth.uid() resolves from the caller's JWT, so it cannot be spoofed to another
-- user. Returns false when unauthenticated or over the limit.
create or replace function public.increment_ai_usage(p_limit int)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_count int;
begin
  if v_user is null then
    return false;
  end if;

  insert into ai_usage (user_id, day, count)
  values (v_user, current_date, 1)
  on conflict (user_id, day)
  do update set count = ai_usage.count + 1
  returning count into v_count;

  return v_count <= p_limit;
end;
$$;

revoke all on function public.increment_ai_usage(int) from public;
grant execute on function public.increment_ai_usage(int) to authenticated;
