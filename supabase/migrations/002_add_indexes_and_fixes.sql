-- Performance indexes and supplementary fixes

-- Prices: lookup by symbol+date (critical for portfolio valuation)
create index idx_prices_symbol_date on prices(symbol, date desc);

-- Transactions: user+date range queries (spending reports)
create index idx_transactions_user_date on transactions(user_id, date desc);

-- Transactions: category aggregation
create index idx_transactions_user_category on transactions(user_id, category_id);

-- Holdings: user portfolio listing
create index idx_holdings_user on holdings(user_id);

-- Investment transactions: holding history
create index idx_inv_tx_holding on investment_transactions(holding_id, date desc);

-- Goals: user listing
create index idx_goals_user on goals(user_id);

-- Insights: unread per user
create index idx_insights_user_unread on insights(user_id) where read = false;

-- Accounts: user listing
create index idx_accounts_user on accounts(user_id);

-- Categories: system categories fast lookup
create index idx_categories_system on categories(is_system) where is_system = true;

-- updated_at trigger function
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_accounts_updated_at before update on accounts for each row execute function update_updated_at();
create trigger trg_holdings_updated_at before update on holdings for each row execute function update_updated_at();
create trigger trg_goals_updated_at before update on goals for each row execute function update_updated_at();
