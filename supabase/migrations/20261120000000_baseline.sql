
-- BAITI JANNATI SOLUTION | PRD v1.1 | PostgreSQL / Supabase baseline
-- Execute only in a staging project first. Review security and accounting policies.
begin;
create extension if not exists pgcrypto;
create extension if not exists citext;
create schema if not exists app;
create schema if not exists accounting;

do $$ begin create type app.doc_status as enum
('draft','submitted','pending_approval','approved','rejected','confirmed','partially_fulfilled','fulfilled','cancelled','void','posted');
exception when duplicate_object then null; end $$;
do $$ begin create type app.import_cost_mode as enum ('purchase_cost_only','full_landed_cost');
exception when duplicate_object then null; end $$;
do $$ begin create type app.allocation_method as enum ('quantity','value','weight','volume','manual');
exception when duplicate_object then null; end $$;
do $$ begin create type app.invoice_kind as enum ('dp','partial','final','standard','credit_note','debit_note');
exception when duplicate_object then null; end $$;
do $$ begin create type app.invoice_status as enum ('draft','issued','partially_paid','paid','overdue','void','cancelled');
exception when duplicate_object then null; end $$;
do $$ begin create type accounting.account_type as enum
('asset','liability','equity','revenue','cost_of_sales','expense','other_income','other_expense');
exception when duplicate_object then null; end $$;
do $$ begin create type accounting.journal_status as enum ('draft','posted','reversed');
exception when duplicate_object then null; end $$;

-- Identity / authorization
create table if not exists app.user_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, email citext, phone text, is_active boolean not null default true,
 created_at timestamptz not null default now()
);
create table if not exists app.roles (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null
);
create table if not exists app.permissions (
 id uuid primary key default gen_random_uuid(), code text unique not null, description text not null
);
create table if not exists app.role_permissions (
 role_id uuid references app.roles(id) on delete cascade,
 permission_id uuid references app.permissions(id) on delete cascade,
 primary key(role_id,permission_id)
);
create table if not exists app.user_roles (
 user_id uuid references app.user_profiles(user_id) on delete cascade,
 role_id uuid references app.roles(id) on delete cascade,
 primary key(user_id,role_id)
);
create table if not exists app.document_sequences (
 document_type text not null, period_key text not null, prefix text not null,
 last_value bigint not null default 0, primary key(document_type,period_key)
);
create or replace function app.next_doc(p_type text,p_prefix text)
returns text language plpgsql security definer set search_path=app,public as $$
declare v_period text := to_char(now() at time zone 'Asia/Jakarta','YYYYMM'); v_n bigint;
begin
 insert into app.document_sequences(document_type,period_key,prefix,last_value)
 values(p_type,v_period,p_prefix,1)
 on conflict(document_type,period_key) do update
 set last_value=app.document_sequences.last_value+1 returning last_value into v_n;
 return p_prefix||'-'||v_period||'-'||lpad(v_n::text,5,'0');
end $$;

-- CRM
create table if not exists app.customers (
 id uuid primary key default gen_random_uuid(), customer_code text unique not null,
 legal_name text not null, brand_name text, customer_type text not null default 'brand_owner',
 status text not null default 'prospect', tax_id text, email citext, phone text,
 billing_address jsonb not null default '{}', shipping_address jsonb not null default '{}',
 currency char(3) not null default 'IDR', payment_term_days int not null default 0 check(payment_term_days>=0),
 credit_limit numeric(20,2) not null default 0 check(credit_limit>=0),
 sales_owner uuid references app.user_profiles(user_id), notes text,
 created_by uuid references app.user_profiles(user_id), created_at timestamptz not null default now()
);
create index if not exists customers_owner_idx on app.customers(sales_owner);
create table if not exists app.customer_contacts (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references app.customers(id),
 full_name text not null, job_title text, email citext, phone text, whatsapp text,
 is_primary boolean not null default false
);
create table if not exists app.leads (
 id uuid primary key default gen_random_uuid(), lead_code text unique not null,
 company_name text not null, contact_name text, email citext, phone text, source text,
 stage text not null default 'new', estimated_value numeric(20,2) default 0,
 probability numeric(5,2) default 0 check(probability between 0 and 100),
 expected_close_date date, sales_owner uuid not null references app.user_profiles(user_id),
 converted_customer_id uuid references app.customers(id), lost_reason text,
 created_at timestamptz not null default now()
);
create table if not exists app.activities (
 id uuid primary key default gen_random_uuid(), customer_id uuid references app.customers(id),
 lead_id uuid references app.leads(id), owner_id uuid not null references app.user_profiles(user_id),
 activity_type text not null, subject text not null, description text, due_at timestamptz,
 completed_at timestamptz, created_at timestamptz not null default now(),
 check(customer_id is not null or lead_id is not null)
);

-- Product, UOM, variants, pricing
create table if not exists app.product_categories (
 id uuid primary key default gen_random_uuid(), parent_id uuid references app.product_categories(id),
 code text unique not null, name text not null
);
create table if not exists app.uoms (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 decimal_allowed boolean not null default false
);
create table if not exists app.products (
 id uuid primary key default gen_random_uuid(), sku text unique not null, name text not null,
 category_id uuid references app.product_categories(id), description text, material text,
 capacity numeric(14,3), capacity_unit text, color text, neck_size text,
 height_mm numeric(12,3), diameter_mm numeric(12,3), country_of_origin text,
 sourcing_type text not null check(sourcing_type in ('local','import','both')),
 uom_id uuid references app.uoms(id), barcode text, min_stock numeric(20,4) default 0,
 reorder_point numeric(20,4) default 0, attributes jsonb not null default '{}',
 is_active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists app.product_variants (
 id uuid primary key default gen_random_uuid(), product_id uuid not null references app.products(id),
 variant_sku text unique not null, variant_name text not null, attributes jsonb not null default '{}',
 barcode text, is_active boolean not null default true
);
create table if not exists app.price_lists (
 id uuid primary key default gen_random_uuid(), name text not null, currency char(3) not null default 'IDR',
 valid_from date, valid_to date, is_default boolean not null default false, is_active boolean not null default true,
 check(valid_to is null or valid_from is null or valid_to>=valid_from)
);
create table if not exists app.price_list_items (
 id uuid primary key default gen_random_uuid(), price_list_id uuid not null references app.price_lists(id),
 product_id uuid not null references app.products(id), min_qty numeric(20,4) not null default 1,
 unit_price numeric(20,4) not null check(unit_price>=0), unique(price_list_id,product_id,min_qty)
);
create table if not exists app.customer_product_prices (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references app.customers(id),
 product_id uuid not null references app.products(id), min_qty numeric(20,4) not null default 1,
 currency char(3) not null default 'IDR', unit_price numeric(20,4) not null check(unit_price>=0),
 valid_from date, valid_to date
);

-- Supplier and purchasing
create table if not exists app.suppliers (
 id uuid primary key default gen_random_uuid(), supplier_code text unique not null,
 legal_name text not null, country text, email citext, phone text, currency char(3) default 'IDR',
 payment_term_days int default 0, tax_id text, address jsonb default '{}',
 bank_details jsonb default '{}', is_active boolean default true
);
create table if not exists app.purchase_requests (
 id uuid primary key default gen_random_uuid(), pr_number text unique not null default app.next_doc('PR','PR'),
 requested_by uuid references app.user_profiles(user_id), required_date date, reason text,
 status app.doc_status not null default 'draft', created_at timestamptz default now()
);
create table if not exists app.purchase_request_items (
 id uuid primary key default gen_random_uuid(), pr_id uuid not null references app.purchase_requests(id),
 product_id uuid not null references app.products(id), quantity numeric(20,4) not null check(quantity>0),
 estimated_unit_cost numeric(20,4) default 0
);
create table if not exists app.purchase_orders (
 id uuid primary key default gen_random_uuid(), po_number text unique not null default app.next_doc('PO','PO'),
 supplier_id uuid not null references app.suppliers(id), pr_id uuid references app.purchase_requests(id),
 order_date date not null default current_date, expected_date date, currency char(3) not null default 'IDR',
 exchange_rate numeric(20,8) not null default 1 check(exchange_rate>0),
 subtotal numeric(20,2) default 0, discount numeric(20,2) default 0, tax numeric(20,2) default 0,
 total numeric(20,2) default 0, status app.doc_status not null default 'draft',
 created_by uuid references app.user_profiles(user_id), approved_by uuid references app.user_profiles(user_id)
);
create table if not exists app.purchase_order_items (
 id uuid primary key default gen_random_uuid(), po_id uuid not null references app.purchase_orders(id),
 product_id uuid not null references app.products(id), quantity numeric(20,4) not null check(quantity>0),
 received_qty numeric(20,4) not null default 0, unit_cost_foreign numeric(20,4) not null,
 unit_cost_base numeric(20,4) not null, weight_kg numeric(20,6), volume_cbm numeric(20,6)
);

-- Import and landed cost
create table if not exists app.import_shipments (
 id uuid primary key default gen_random_uuid(), shipment_no text unique not null default app.next_doc('IMP','IMP'),
 po_id uuid not null references app.purchase_orders(id), supplier_id uuid not null references app.suppliers(id),
 origin_country text, shipping_method text not null, forwarder text, incoterm text,
 bl_awb text, container_no text, etd date, eta date, actual_arrival date,
 currency char(3) not null, exchange_rate numeric(20,8) not null check(exchange_rate>0),
 cost_mode app.import_cost_mode not null, allocation_method app.allocation_method not null,
 status text not null default 'planned'
);
create table if not exists app.import_shipment_items (
 id uuid primary key default gen_random_uuid(), shipment_id uuid not null references app.import_shipments(id),
 po_item_id uuid not null references app.purchase_order_items(id), product_id uuid not null references app.products(id),
 quantity numeric(20,4) not null check(quantity>0), allocated_cost numeric(20,2) not null default 0
);
create table if not exists app.import_costs (
 id uuid primary key default gen_random_uuid(), shipment_id uuid not null references app.import_shipments(id),
 cost_category text not null, description text, amount_foreign numeric(20,2) default 0,
 currency char(3) not null, exchange_rate numeric(20,8) not null check(exchange_rate>0),
 amount_base numeric(20,2) not null, capitalizable boolean not null default true,
 allocation_method app.allocation_method, vendor_name text, bill_reference text
);
create table if not exists app.import_documents (
 id uuid primary key default gen_random_uuid(), shipment_id uuid not null references app.import_shipments(id),
 document_type text not null, file_path text not null, document_number text, issue_date date
);

-- Warehouse and inventory ledger
create table if not exists app.warehouses (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 warehouse_type text not null default 'general', address jsonb default '{}', is_active boolean default true
);
create table if not exists app.stock_balances (
 id uuid primary key default gen_random_uuid(), warehouse_id uuid not null references app.warehouses(id),
 product_id uuid not null references app.products(id), on_hand numeric(20,4) not null default 0,
 reserved numeric(20,4) not null default 0, average_unit_cost numeric(20,6) not null default 0,
 updated_at timestamptz not null default now(), unique(warehouse_id,product_id),
 check(on_hand>=0), check(reserved>=0 and reserved<=on_hand)
);
create table if not exists app.stock_movements (
 id uuid primary key default gen_random_uuid(), movement_no text unique not null default app.next_doc('STK','STK'),
 warehouse_id uuid not null references app.warehouses(id), product_id uuid not null references app.products(id),
 movement_type text not null, quantity numeric(20,4) not null check(quantity>0),
 unit_cost numeric(20,6) not null default 0, total_cost numeric(20,2) not null default 0,
 source_type text not null, source_id uuid not null, occurred_at timestamptz not null default now(),
 posted_at timestamptz, posted_by uuid references app.user_profiles(user_id), notes text
);
create index if not exists stock_movements_product_date_idx on app.stock_movements(product_id,occurred_at);
create table if not exists app.stock_reservations (
 id uuid primary key default gen_random_uuid(), so_id uuid, so_item_id uuid,
 warehouse_id uuid not null references app.warehouses(id), product_id uuid not null references app.products(id),
 quantity numeric(20,4) not null check(quantity>0), released_qty numeric(20,4) default 0,
 status text not null default 'active', expires_at timestamptz
);
create table if not exists app.stock_transfers (
 id uuid primary key default gen_random_uuid(), transfer_no text unique not null default app.next_doc('TRF','TRF'),
 from_warehouse_id uuid not null references app.warehouses(id),
 to_warehouse_id uuid not null references app.warehouses(id), status app.doc_status default 'draft',
 requested_by uuid references app.user_profiles(user_id), approved_by uuid references app.user_profiles(user_id),
 check(from_warehouse_id<>to_warehouse_id)
);
create table if not exists app.stock_transfer_items (
 id uuid primary key default gen_random_uuid(), transfer_id uuid not null references app.stock_transfers(id),
 product_id uuid not null references app.products(id), quantity numeric(20,4) not null check(quantity>0)
);

-- Sales, quotations, orders, delivery
create table if not exists app.quotations (
 id uuid primary key default gen_random_uuid(), quotation_no text unique not null default app.next_doc('QT','QT'),
 customer_id uuid not null references app.customers(id), sales_owner uuid not null references app.user_profiles(user_id),
 quote_date date not null default current_date, valid_until date, currency char(3) default 'IDR',
 exchange_rate numeric(20,8) default 1, subtotal numeric(20,2) default 0,
 discount numeric(20,2) default 0, tax numeric(20,2) default 0, shipping numeric(20,2) default 0,
 grand_total numeric(20,2) default 0, status app.doc_status default 'draft', notes text
);
create table if not exists app.quotation_items (
 id uuid primary key default gen_random_uuid(), quotation_id uuid not null references app.quotations(id),
 product_id uuid not null references app.products(id), description text,
 quantity numeric(20,4) not null check(quantity>0), unit_price numeric(20,4) not null,
 discount_pct numeric(7,4) default 0, tax_rate numeric(7,4) default 0, line_total numeric(20,2) default 0,
 price_source text
);
create table if not exists app.sales_orders (
 id uuid primary key default gen_random_uuid(), so_number text unique not null default app.next_doc('SO','SO'),
 customer_id uuid not null references app.customers(id), quotation_id uuid references app.quotations(id),
 sales_owner uuid not null references app.user_profiles(user_id), order_date date default current_date,
 requested_delivery_date date, currency char(3) default 'IDR', exchange_rate numeric(20,8) default 1,
 subtotal numeric(20,2) default 0, discount numeric(20,2) default 0, tax numeric(20,2) default 0,
 grand_total numeric(20,2) default 0, status app.doc_status default 'draft'
);
create table if not exists app.sales_order_items (
 id uuid primary key default gen_random_uuid(), so_id uuid not null references app.sales_orders(id),
 product_id uuid not null references app.products(id), quantity numeric(20,4) not null check(quantity>0),
 delivered_qty numeric(20,4) default 0, invoiced_qty numeric(20,4) default 0,
 unit_price numeric(20,4) not null, discount_amount numeric(20,2) default 0,
 tax_rate numeric(7,4) default 0, line_total numeric(20,2) default 0
);
create table if not exists app.delivery_orders (
 id uuid primary key default gen_random_uuid(), do_number text unique not null default app.next_doc('DO','DO'),
 so_id uuid not null references app.sales_orders(id), warehouse_id uuid not null references app.warehouses(id),
 delivery_date date default current_date, recipient_name text, delivery_address jsonb default '{}',
 courier text, tracking_number text, status app.doc_status default 'draft', posted_at timestamptz
);
create table if not exists app.delivery_order_items (
 id uuid primary key default gen_random_uuid(), do_id uuid not null references app.delivery_orders(id),
 so_item_id uuid not null references app.sales_order_items(id), product_id uuid not null references app.products(id),
 quantity numeric(20,4) not null check(quantity>0)
);

-- Tax, invoicing and payment
create table if not exists app.tax_codes (
 id uuid primary key default gen_random_uuid(), code text unique not null, name text not null,
 rate numeric(7,4) not null default 0, tax_type text not null, effective_from date, effective_to date,
 is_active boolean default true
);
create table if not exists app.invoices (
 id uuid primary key default gen_random_uuid(), invoice_no text unique not null default app.next_doc('INV','INV'),
 customer_id uuid not null references app.customers(id), so_id uuid references app.sales_orders(id),
 do_id uuid references app.delivery_orders(id), invoice_type app.invoice_kind not null,
 invoice_date date not null default current_date, due_date date, currency char(3) default 'IDR',
 exchange_rate numeric(20,8) default 1, subtotal numeric(20,2) default 0,
 discount numeric(20,2) default 0, tax numeric(20,2) default 0, total numeric(20,2) default 0,
 amount_paid numeric(20,2) default 0, balance_due numeric(20,2) default 0,
 status app.invoice_status default 'draft', posted_journal_id uuid
);
create table if not exists app.invoice_items (
 id uuid primary key default gen_random_uuid(), invoice_id uuid not null references app.invoices(id),
 so_item_id uuid references app.sales_order_items(id), product_id uuid references app.products(id),
 description text not null, quantity numeric(20,4) default 1, unit_price numeric(20,4) default 0,
 discount_amount numeric(20,2) default 0, tax_code_id uuid references app.tax_codes(id),
 tax_rate numeric(7,4) default 0, line_total numeric(20,2) default 0
);
create table if not exists app.credit_notes (
 id uuid primary key default gen_random_uuid(), credit_note_no text unique not null default app.next_doc('CN','CN'),
 invoice_id uuid not null references app.invoices(id), issue_date date default current_date,
 reason text not null, amount numeric(20,2) not null check(amount>0), status app.doc_status default 'draft'
);
create table if not exists app.payments (
 id uuid primary key default gen_random_uuid(), payment_no text unique not null default app.next_doc('PAY','PAY'),
 direction text not null check(direction in ('in','out')), party_type text not null,
 customer_id uuid references app.customers(id), supplier_id uuid references app.suppliers(id),
 payment_date date default current_date, currency char(3) default 'IDR',
 exchange_rate numeric(20,8) default 1, amount numeric(20,2) not null check(amount>0),
 bank_account_id uuid, payment_method text, reference_number text,
 status text default 'draft', created_by uuid references app.user_profiles(user_id), posted_at timestamptz
);
create table if not exists app.payment_allocations (
 id uuid primary key default gen_random_uuid(), payment_id uuid not null references app.payments(id),
 invoice_id uuid references app.invoices(id), allocated_amount numeric(20,2) not null check(allocated_amount>0),
 check(invoice_id is not null)
);

-- Accounting
create table if not exists accounting.fiscal_years (
 id uuid primary key default gen_random_uuid(), name text unique not null,
 start_date date not null, end_date date not null, is_closed boolean default false,
 check(end_date>=start_date)
);
create table if not exists accounting.periods (
 id uuid primary key default gen_random_uuid(), fiscal_year_id uuid not null references accounting.fiscal_years(id),
 period_no int not null check(period_no between 1 and 13), start_date date not null, end_date date not null,
 is_closed boolean default false, unique(fiscal_year_id,period_no), check(end_date>=start_date)
);
create table if not exists accounting.chart_of_accounts (
 id uuid primary key default gen_random_uuid(), account_code text unique not null,
 account_name text not null, account_type accounting.account_type not null,
 parent_id uuid references accounting.chart_of_accounts(id),
 normal_balance text not null check(normal_balance in ('debit','credit')),
 is_control_account boolean default false, is_active boolean default true,
 allow_manual_posting boolean default true
);
create table if not exists accounting.journals (
 id uuid primary key default gen_random_uuid(), journal_no text unique not null default app.next_doc('JRN','JRN'),
 journal_date date not null default current_date, description text not null,
 source_module text, source_type text, source_id uuid,
 status accounting.journal_status not null default 'draft',
 reversal_of uuid references accounting.journals(id), created_by uuid references app.user_profiles(user_id),
 posted_by uuid references app.user_profiles(user_id), posted_at timestamptz
);
create table if not exists accounting.journal_lines (
 id uuid primary key default gen_random_uuid(), journal_id uuid not null references accounting.journals(id),
 account_id uuid not null references accounting.chart_of_accounts(id), description text,
 debit numeric(20,2) not null default 0 check(debit>=0),
 credit numeric(20,2) not null default 0 check(credit>=0),
 customer_id uuid references app.customers(id), supplier_id uuid references app.suppliers(id),
 product_id uuid references app.products(id), warehouse_id uuid references app.warehouses(id),
 check((debit=0 and credit>0) or (credit=0 and debit>0))
);
create table if not exists accounting.bank_accounts (
 id uuid primary key default gen_random_uuid(), account_name text not null, bank_name text not null,
 masked_account_number text, currency char(3) default 'IDR',
 gl_account_id uuid not null references accounting.chart_of_accounts(id), is_active boolean default true
);
create table if not exists accounting.expenses (
 id uuid primary key default gen_random_uuid(), expense_no text unique not null default app.next_doc('EXP','EXP'),
 expense_date date default current_date, category text not null, description text not null,
 amount numeric(20,2) not null check(amount>0), currency char(3) default 'IDR',
 exchange_rate numeric(20,8) default 1, supplier_id uuid references app.suppliers(id),
 status app.doc_status default 'draft', journal_id uuid references accounting.journals(id)
);

-- Approval, AI, notification, audit
create table if not exists app.approval_requests (
 id uuid primary key default gen_random_uuid(), entity_type text not null, entity_id uuid not null,
 requested_by uuid not null references app.user_profiles(user_id), requested_action text not null,
 reason text, amount numeric(20,2), status text not null default 'pending',
 decided_by uuid references app.user_profiles(user_id), decided_at timestamptz, decision_note text,
 created_at timestamptz default now()
);
create table if not exists app.approval_policies (
 id uuid primary key default gen_random_uuid(), action_code text unique not null,
 requires_approval boolean default true, amount_threshold numeric(20,2),
 approver_role_code text not null default 'owner_director', configuration jsonb default '{}',
 is_active boolean default true
);
create table if not exists app.ai_agents (
 id uuid primary key default gen_random_uuid(), agent_code text unique not null, name text not null,
 purpose text not null, is_enabled boolean default true, autonomy_level text default 'delegated',
 allowed_tools jsonb default '[]', denied_actions jsonb default '[]', daily_action_limit int default 100
);
create table if not exists app.ai_action_logs (
 id uuid primary key default gen_random_uuid(), agent_id uuid references app.ai_agents(id),
 initiated_by uuid references app.user_profiles(user_id), action_code text not null,
 entity_type text, entity_id uuid, input_payload jsonb default '{}', output_payload jsonb default '{}',
 risk_level text default 'low', approval_request_id uuid references app.approval_requests(id),
 status text default 'proposed', executed_at timestamptz, created_at timestamptz default now()
);
create table if not exists app.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid references app.user_profiles(user_id),
 title text not null, body text not null, category text not null, entity_type text, entity_id uuid,
 read_at timestamptz, created_at timestamptz default now()
);
create table if not exists app.activity_logs (
 id bigserial primary key, actor_user_id uuid references app.user_profiles(user_id),
 actor_type text not null default 'user', action text not null, entity_type text not null,
 entity_id uuid, before_data jsonb, after_data jsonb, created_at timestamptz default now()
);

-- Accounting validation and posting helper
create or replace function accounting.journal_balanced(p_id uuid)
returns boolean language sql stable as $$
 select coalesce(sum(debit),0)=coalesce(sum(credit),0) and coalesce(sum(debit),0)>0
 from accounting.journal_lines where journal_id=p_id
$$;
create or replace function accounting.post_journal(p_id uuid,p_user uuid)
returns void language plpgsql security definer set search_path=accounting,app,public as $$
declare v_date date;
begin
 select journal_date into v_date from accounting.journals where id=p_id for update;
 if not found then raise exception 'Journal not found'; end if;
 if exists(select 1 from accounting.periods where v_date between start_date and end_date and is_closed)
 then raise exception 'Accounting period is closed'; end if;
 if not accounting.journal_balanced(p_id) then raise exception 'Journal is not balanced'; end if;
 update accounting.journals set status='posted',posted_by=p_user,posted_at=now()
 where id=p_id and status='draft';
 if not found then raise exception 'Only draft journal can be posted'; end if;
end $$;

-- RBAC helpers
create or replace function app.has_role(p_role text)
returns boolean language sql stable security definer set search_path=app,public as $$
 select exists(select 1 from app.user_roles ur join app.roles r on r.id=ur.role_id
 where ur.user_id=auth.uid() and r.code=p_role)
$$;
create or replace function app.is_owner_director()
returns boolean language sql stable security definer set search_path=app,public as $$
 select app.has_role('owner') or app.has_role('director')
$$;

-- RLS: enable on sensitive/core tables. Complete policies for every table before go-live.
alter table app.user_profiles enable row level security;
alter table app.customers enable row level security;
alter table app.customer_contacts enable row level security;
alter table app.leads enable row level security;
alter table app.activities enable row level security;
alter table app.products enable row level security;
alter table app.quotations enable row level security;
alter table app.sales_orders enable row level security;
alter table app.invoices enable row level security;
alter table app.stock_balances enable row level security;
alter table app.stock_movements enable row level security;
alter table app.purchase_orders enable row level security;
alter table app.import_shipments enable row level security;
alter table app.payments enable row level security;
alter table app.approval_requests enable row level security;
alter table app.activity_logs enable row level security;

create policy profile_self_read on app.user_profiles for select to authenticated
using (user_id=auth.uid() or app.is_owner_director());
create policy customer_owner_read on app.customers for select to authenticated
using (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'));
create policy customer_owner_insert on app.customers for insert to authenticated
with check (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'));
create policy customer_owner_update on app.customers for update to authenticated
using (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'))
with check (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'));
create policy lead_owner_all on app.leads for all to authenticated
using (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'))
with check (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'));
create policy activity_owner_all on app.activities for all to authenticated
using (owner_id=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'))
with check (owner_id=auth.uid() or app.is_owner_director() or app.has_role('sales_manager'));
create policy product_read_auth on app.products for select to authenticated using (true);
create policy quote_owner_all on app.quotations for all to authenticated
using (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager') or app.has_role('finance'))
with check (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager') or app.has_role('finance'));
create policy so_owner_all on app.sales_orders for all to authenticated
using (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager') or app.has_role('warehouse') or app.has_role('finance'))
with check (sales_owner=auth.uid() or app.is_owner_director() or app.has_role('sales_manager') or app.has_role('warehouse') or app.has_role('finance'));
create policy stock_balance_read on app.stock_balances for select to authenticated using (true);
create policy stock_movement_read on app.stock_movements for select to authenticated using (true);
create policy invoice_finance_read on app.invoices for select to authenticated
using (app.is_owner_director() or app.has_role('finance') or app.has_role('sales_manager'));
create policy payment_finance_read on app.payments for select to authenticated
using (app.is_owner_director() or app.has_role('finance'));
create policy approval_request_read on app.approval_requests for select to authenticated
using (requested_by=auth.uid() or app.is_owner_director());
create policy audit_owner_read on app.activity_logs for select to authenticated
using (app.is_owner_director());

insert into app.roles(code,name) values
('owner','Owner'),('director','Director'),('sales_manager','Sales Manager'),('sales','Sales'),
('purchasing','Purchasing'),('warehouse','Warehouse'),('finance','Finance'),
('product_admin','Product Admin'),('viewer','Management Viewer')
on conflict(code) do nothing;

insert into app.permissions(code,description) values
('crm.read','Read CRM'),('crm.write','Write CRM in ownership scope'),
('sales.read','Read sales'),('sales.write','Write sales'),
('purchasing.manage','Manage purchasing'),('inventory.read','Read inventory'),
('inventory.post','Post inventory movements'),('import.manage','Manage import'),
('invoice.issue','Issue invoice'),('finance.manage','Manage finance'),
('accounting.post','Post journals'),('approval.decide','Decide approvals'),
('users.manage','Manage users'),('audit.read','Read audit'),('ai.policy','Manage AI policy')
on conflict(code) do nothing;

commit;

-- IMPLEMENTATION REQUIRED BEFORE PRODUCTION:
-- A. Add explicit default-deny RLS policies/grants for every remaining table and operation.
-- B. Implement server-only transactional posting functions for receipt, issue, transfer,
--    reservation, DO, returns, stock count, landed-cost allocation and revaluation.
-- C. Implement moving weighted average issue valuation and serialized updates per
--    (warehouse_id, product_id); this migration defines schema, not complete stock engine.
-- D. Implement journal generation/mapping for every subledger event, supplier bills/AP,
--    customer advances, COGS, inventory, tax, FX, bank reconciliation, fixed assets.
-- E. Implement invoice/payment allocation constraints, idempotency keys, outbox queue,
--    immutable posted rows, reversal workflows and complete audit triggers.
-- F. Add company_id to transactional tables before multi-entity operation.
-- G. Review security-definer grants/search_path, Supabase exposed schemas, RLS and tax rules.
-- H. Test concurrency, RLS, ledger reconciliation, landed cost, opening balances and restore.
