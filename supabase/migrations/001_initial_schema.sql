-- FinTrack Initial Schema
-- 8 tables with RLS policies

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. accounts
create table accounts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  type text not null check (type in ('bank','wallet','credit_card','cash','investment')),
  balance numeric(15,2) default 0,
  currency text default 'INR',
  metadata jsonb default '{}',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. categories
create table categories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade,
  name text not null,
  slug text not null,
  type text not null check (type in ('expense','income','transfer')),
  icon text,
  is_system boolean default false,
  created_at timestamptz default now()
);

-- 3. transactions
create table transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid not null references accounts(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  amount numeric(15,2) not null,
  type text not null check (type in ('expense','income','transfer')),
  description text,
  merchant text,
  date date not null default current_date,
  source text default 'manual' check (source in ('manual','sms','upi','import')),
  metadata jsonb default '{}',
  created_at timestamptz default now()
);

-- 4. holdings
create table holdings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  account_id uuid references accounts(id) on delete set null,
  symbol text not null,
  name text not null,
  type text not null check (type in ('stock','mutual_fund','etf','bond','crypto','gold')),
  quantity numeric(15,4) not null default 0,
  avg_buy_price numeric(15,4) not null default 0,
  currency text default 'INR',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 5. investment_transactions
create table investment_transactions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  holding_id uuid not null references holdings(id) on delete cascade,
  type text not null check (type in ('buy','sell','dividend','split','bonus')),
  quantity numeric(15,4) not null,
  price numeric(15,4) not null,
  fees numeric(15,2) default 0,
  date date not null default current_date,
  notes text,
  created_at timestamptz default now()
);

-- 6. prices
create table prices (
  id uuid primary key default uuid_generate_v4(),
  symbol text not null,
  date date not null,
  open numeric(15,4),
  high numeric(15,4),
  low numeric(15,4),
  close numeric(15,4) not null,
  nav numeric(15,4),
  source text,
  created_at timestamptz default now(),
  unique(symbol, date)
);

-- 7. goals
create table goals (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  target_amount numeric(15,2) not null,
  current_amount numeric(15,2) default 0,
  target_date date,
  category text,
  status text default 'active' check (status in ('active','completed','cancelled')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 8. insights
create table insights (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb default '{}',
  read boolean default false,
  created_at timestamptz default now()
);

-- ===== RLS POLICIES =====

alter table accounts enable row level security;
create policy "Users manage own accounts" on accounts for all using (auth.uid() = user_id);

alter table categories enable row level security;
create policy "Users see system + own categories" on categories for select using (is_system = true or auth.uid() = user_id);
create policy "Users manage own categories" on categories for insert with check (auth.uid() = user_id);
create policy "Users update own categories" on categories for update using (auth.uid() = user_id);
create policy "Users delete own categories" on categories for delete using (auth.uid() = user_id and is_system = false);

alter table transactions enable row level security;
create policy "Users manage own transactions" on transactions for all using (auth.uid() = user_id);

alter table holdings enable row level security;
create policy "Users manage own holdings" on holdings for all using (auth.uid() = user_id);

alter table investment_transactions enable row level security;
create policy "Users manage own investment_transactions" on investment_transactions for all using (auth.uid() = user_id);

alter table prices enable row level security;
create policy "Prices are readable by all authenticated" on prices for select using (auth.role() = 'authenticated');

alter table goals enable row level security;
create policy "Users manage own goals" on goals for all using (auth.uid() = user_id);

alter table insights enable row level security;
create policy "Users manage own insights" on insights for all using (auth.uid() = user_id);
