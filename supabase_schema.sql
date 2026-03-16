-- ============================================================
-- TindaKo - Supabase Schema
-- Run this in your Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── User profiles (linked to Supabase Auth) ──────────────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  store_name  text not null default 'My Sari-sari Store',
  is_premium  boolean not null default false,
  created_at  timestamptz not null default now()
);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── Categories ───────────────────────────────────────────────
create table public.categories (
  sync_id     uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- ── Products ─────────────────────────────────────────────────
create table public.products (
  sync_id             uuid primary key default uuid_generate_v4(),
  user_id             uuid not null references auth.users(id) on delete cascade,
  category_sync_id    uuid references public.categories(sync_id),
  name                text not null,
  description         text,
  unit                text not null default 'pc',
  barcode             text,
  price_cents         integer not null default 0,
  cost_cents          integer,
  stock_qty           integer not null default 0,
  low_stock_threshold integer not null default 5,
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

-- ── Customers ────────────────────────────────────────────────
create table public.customers (
  sync_id       uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  phone         text,
  address       text,
  notes         text,
  balance_cents integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  deleted_at    timestamptz
);

-- ── Invoices ─────────────────────────────────────────────────
create table public.invoices (
  sync_id              uuid primary key default uuid_generate_v4(),
  user_id              uuid not null references auth.users(id) on delete cascade,
  customer_sync_id     uuid references public.customers(sync_id),
  invoice_no           text not null,
  type                 text not null,
  status               text not null default 'active',
  subtotal_cents       integer not null default 0,
  discount_cents       integer not null default 0,
  total_cents          integer not null default 0,
  cash_received_cents  integer,
  change_cents         integer,
  balance_before_cents integer,
  balance_after_cents  integer,
  notes                text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

-- ── Invoice Items ────────────────────────────────────────────
create table public.invoice_items (
  sync_id               uuid primary key default uuid_generate_v4(),
  user_id               uuid not null references auth.users(id) on delete cascade,
  invoice_sync_id       uuid not null references public.invoices(sync_id) on delete cascade,
  product_sync_id       uuid references public.products(sync_id),
  product_name_snapshot text not null,
  unit_snapshot         text not null,
  price_snapshot_cents  integer not null,
  qty                   integer not null,
  line_total_cents      integer not null
);

-- ── Customer Payments ────────────────────────────────────────
create table public.customer_payments (
  sync_id          uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  customer_sync_id uuid not null references public.customers(sync_id),
  invoice_sync_id  uuid references public.invoices(sync_id),
  amount_cents     integer not null,
  notes            text,
  created_at       timestamptz not null default now()
);

-- ── Stock Movements ──────────────────────────────────────────
create table public.stock_movements (
  sync_id          uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  product_sync_id  uuid not null references public.products(sync_id),
  change_qty       integer not null,
  reason           text not null,
  reference_sync_id uuid,
  notes            text,
  created_at       timestamptz not null default now()
);

-- ── Row Level Security (each user sees only their data) ──────
alter table public.profiles         enable row level security;
alter table public.categories       enable row level security;
alter table public.products         enable row level security;
alter table public.customers        enable row level security;
alter table public.invoices         enable row level security;
alter table public.invoice_items    enable row level security;
alter table public.customer_payments enable row level security;
alter table public.stock_movements  enable row level security;

-- Profiles: user can only read/update their own
create policy "own profile" on public.profiles
  for all using (auth.uid() = id);

-- All other tables: user can only access their own rows
create policy "own data" on public.categories
  for all using (auth.uid() = user_id);
create policy "own data" on public.products
  for all using (auth.uid() = user_id);
create policy "own data" on public.customers
  for all using (auth.uid() = user_id);
create policy "own data" on public.invoices
  for all using (auth.uid() = user_id);
create policy "own data" on public.invoice_items
  for all using (auth.uid() = user_id);
create policy "own data" on public.customer_payments
  for all using (auth.uid() = user_id);
create policy "own data" on public.stock_movements
  for all using (auth.uid() = user_id);

-- ── Indexes for performance ──────────────────────────────────
create index on public.products(user_id, updated_at);
create index on public.customers(user_id, updated_at);
create index on public.invoices(user_id, updated_at);
create index on public.invoice_items(invoice_sync_id);
create index on public.customer_payments(customer_sync_id);
create index on public.stock_movements(product_sync_id);
