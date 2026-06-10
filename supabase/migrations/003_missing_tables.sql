-- Missing tables referenced by investment_providers.dart
create table if not exists price_cache (
  id uuid primary key default gen_random_uuid(),
  symbol text not null,
  price numeric(12,4) not null,
  day_change numeric(12,4) default 0,
  updated_at timestamptz default now(),
  unique(symbol)
);

create table if not exists portfolio_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  value numeric(15,2) not null,
  date date not null default current_date,
  unique(user_id, date)
);

alter table portfolio_snapshots enable row level security;
create policy "Users see own snapshots" on portfolio_snapshots for all using (auth.uid() = user_id);

-- Missing column
alter table holdings add column if not exists purchase_date date;
