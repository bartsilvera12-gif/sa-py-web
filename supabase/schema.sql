-- ═══════════════════════════════════════════════════════════════════════════
-- Seguridad Alimentaria PY — Supabase schema
-- Self-host · Postgres 15+
-- Run in the Supabase SQL editor (or psql) against a fresh project.
-- ═══════════════════════════════════════════════════════════════════════════

-- Extensions ---------------------------------------------------------------
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- Schema -------------------------------------------------------------------
create schema if not exists seguridadalimentaria;
set search_path to seguridadalimentaria, public;

-- Reusable helper: keep updated_at fresh
create or replace function seguridadalimentaria.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

-- Role helper: does the current JWT belong to an admin? -------------------
-- We store the role in raw_app_meta_data.role (Supabase convention).
create or replace function seguridadalimentaria.is_admin()
returns boolean language sql stable as $$
  select coalesce(
    (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
    or (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin',
    false
  );
$$;

-- ═══════════════════════════════ TABLES ══════════════════════════════════

-- 1. categories ----------------------------------------------------------
create table seguridadalimentaria.categories (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  slug         text not null unique,
  description  text,
  icon         text,                       -- lucide/inline icon key
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create index on seguridadalimentaria.categories (is_active, sort_order);

-- 2. products ------------------------------------------------------------
create table seguridadalimentaria.products (
  id                    uuid primary key default gen_random_uuid(),
  category_id           uuid references seguridadalimentaria.categories(id) on delete set null,
  name                  text not null,
  slug                  text not null unique,
  short_description     text,
  description           text,
  benefits              text[] default '{}',
  usage_recommendations text[] default '{}',
  tags                  text[] default '{}',
  price                 numeric(14,2),
  show_price            boolean not null default false,
  stock                 int not null default 0,
  is_featured           boolean not null default false,
  is_active             boolean not null default true,
  sort_order            int not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);
create index on seguridadalimentaria.products (is_active, is_featured, sort_order);
create index on seguridadalimentaria.products (category_id);
create index on seguridadalimentaria.products using gin (tags);
create trigger products_touch before update on seguridadalimentaria.products
  for each row execute function seguridadalimentaria.touch_updated_at();

-- 3. product_images ------------------------------------------------------
create table seguridadalimentaria.product_images (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references seguridadalimentaria.products(id) on delete cascade,
  image_url   text not null,               -- Supabase Storage public URL
  alt_text    text,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);
create index on seguridadalimentaria.product_images (product_id, sort_order);

-- 4. orders --------------------------------------------------------------
create table seguridadalimentaria.orders (
  id                uuid primary key default gen_random_uuid(),
  customer_name     text not null,
  customer_phone    text not null,
  customer_company  text,
  customer_ruc      text,
  customer_city     text,
  notes             text,
  status            text not null default 'pendiente'
                    check (status in ('pendiente','contactado','cotizado','cerrado','cancelado')),
  total_estimated   numeric(14,2),
  whatsapp_message  text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index on seguridadalimentaria.orders (status, created_at desc);
create trigger orders_touch before update on seguridadalimentaria.orders
  for each row execute function seguridadalimentaria.touch_updated_at();

-- 5. order_items ---------------------------------------------------------
create table seguridadalimentaria.order_items (
  id           uuid primary key default gen_random_uuid(),
  order_id     uuid not null references seguridadalimentaria.orders(id) on delete cascade,
  product_id   uuid references seguridadalimentaria.products(id) on delete set null,
  product_name text not null,              -- snapshot in case product renamed/deleted
  product_sku  text,
  quantity     int not null default 1 check (quantity > 0),
  unit_price   numeric(14,2),
  created_at   timestamptz not null default now()
);
create index on seguridadalimentaria.order_items (order_id);

-- 6. contact_requests ----------------------------------------------------
create table seguridadalimentaria.contact_requests (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  phone      text,
  email      text,
  company    text,
  industry   text,
  message    text not null,
  status     text not null default 'nuevo'
             check (status in ('nuevo','respondido','descartado')),
  created_at timestamptz not null default now()
);
create index on seguridadalimentaria.contact_requests (status, created_at desc);

-- 7. site_settings -------------------------------------------------------
create table seguridadalimentaria.site_settings (
  id         uuid primary key default gen_random_uuid(),
  key        text not null unique,
  value      jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger site_settings_touch before update on seguridadalimentaria.site_settings
  for each row execute function seguridadalimentaria.touch_updated_at();

-- ═══════════════════════════════ RLS ═════════════════════════════════════
alter table seguridadalimentaria.categories        enable row level security;
alter table seguridadalimentaria.products          enable row level security;
alter table seguridadalimentaria.product_images    enable row level security;
alter table seguridadalimentaria.orders            enable row level security;
alter table seguridadalimentaria.order_items       enable row level security;
alter table seguridadalimentaria.contact_requests  enable row level security;
alter table seguridadalimentaria.site_settings     enable row level security;

-- Categorías: lectura pública sólo activas
create policy "categories_read_active"
  on seguridadalimentaria.categories for select
  using (is_active = true or seguridadalimentaria.is_admin());

create policy "categories_admin_all"
  on seguridadalimentaria.categories for all
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

-- Products: lectura pública sólo activas
create policy "products_read_active"
  on seguridadalimentaria.products for select
  using (is_active = true or seguridadalimentaria.is_admin());

create policy "products_admin_all"
  on seguridadalimentaria.products for all
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

-- Product images: público lee las de productos activos
create policy "product_images_read_active"
  on seguridadalimentaria.product_images for select
  using (
    exists (
      select 1 from seguridadalimentaria.products p
      where p.id = product_id and (p.is_active = true or seguridadalimentaria.is_admin())
    )
  );

create policy "product_images_admin_all"
  on seguridadalimentaria.product_images for all
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

-- Orders: inserts públicos (checkout); lectura/edición sólo admin
create policy "orders_insert_public"
  on seguridadalimentaria.orders for insert
  with check (true);

create policy "orders_read_admin"
  on seguridadalimentaria.orders for select
  using (seguridadalimentaria.is_admin());

create policy "orders_update_admin"
  on seguridadalimentaria.orders for update
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

create policy "orders_delete_admin"
  on seguridadalimentaria.orders for delete
  using (seguridadalimentaria.is_admin());

-- Order items: mismo patrón que orders
create policy "order_items_insert_public"
  on seguridadalimentaria.order_items for insert
  with check (true);

create policy "order_items_read_admin"
  on seguridadalimentaria.order_items for select
  using (seguridadalimentaria.is_admin());

create policy "order_items_admin_write"
  on seguridadalimentaria.order_items for all
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

-- Contact requests: inserts públicos; el resto admin
create policy "contact_insert_public"
  on seguridadalimentaria.contact_requests for insert
  with check (true);

create policy "contact_admin_read"
  on seguridadalimentaria.contact_requests for select
  using (seguridadalimentaria.is_admin());

create policy "contact_admin_write"
  on seguridadalimentaria.contact_requests for all
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

-- Site settings: lectura pública, escritura admin
create policy "settings_read_public"
  on seguridadalimentaria.site_settings for select
  using (true);

create policy "settings_admin_write"
  on seguridadalimentaria.site_settings for all
  using (seguridadalimentaria.is_admin())
  with check (seguridadalimentaria.is_admin());

-- ═══════════════════════════════ STORAGE ═════════════════════════════════
-- Ejecutar desde el Dashboard o via SQL en el esquema `storage`.
-- Buckets: product-images (público) y brand-assets (público).

insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('brand-assets', 'brand-assets', true)
on conflict (id) do nothing;

-- Storage policies: lectura pública, escritura sólo admin.
create policy "storage_public_read_product_images"
  on storage.objects for select
  using (bucket_id = 'product-images');

create policy "storage_admin_write_product_images"
  on storage.objects for all
  using (bucket_id = 'product-images' and seguridadalimentaria.is_admin())
  with check (bucket_id = 'product-images' and seguridadalimentaria.is_admin());

create policy "storage_public_read_brand_assets"
  on storage.objects for select
  using (bucket_id = 'brand-assets');

create policy "storage_admin_write_brand_assets"
  on storage.objects for all
  using (bucket_id = 'brand-assets' and seguridadalimentaria.is_admin())
  with check (bucket_id = 'brand-assets' and seguridadalimentaria.is_admin());

-- ═══════════════════════════════ SEED ════════════════════════════════════
-- Categorías iniciales
insert into seguridadalimentaria.categories (name, slug, description, icon, sort_order) values
  ('Cintillos y cadenas de seguridad', 'cintillos-cadenas', 'Bandas, cierres y sistemas de delimitación detectables para áreas críticas de producción.', 'chain', 10),
  ('Productos detectables', 'productos-detectables', 'Bolígrafos, marcadores, herramientas y accesorios con materiales detectables por metales.', 'detect', 20),
  ('Corte y manipulación', 'corte-manipulacion', 'Cuchillería profesional, chairas y utensilios de corte con mangos detectables.', 'knife', 30),
  ('Packaging gastronómico', 'packaging-gastronomico', 'Bandejas, cajas kraft, papel manteca personalizado y contenedores para take away.', 'pack', 40),
  ('Higiene y control', 'higiene-control', 'Guantes, curitas, dosificadores, delantales, termómetros y kits de sanitización.', 'clean', 50),
  ('Soluciones para industrias alimentarias', 'soluciones-industria', 'Insumos técnicos, equipamiento y consultoría para plantas HACCP, ISO y BRCGS.', 'industry', 60)
on conflict (slug) do nothing;

-- Site settings iniciales
insert into seguridadalimentaria.site_settings (key, value) values
  ('whatsapp_number', '"595982296371"'::jsonb),
  ('company_email',   '"info@laseguridadalimentaria.com"'::jsonb),
  ('company_address', '"Cap. Rigoberto Fontao 335, Asunción, Paraguay"'::jsonb),
  ('hero_title',      '"Soluciones profesionales para la seguridad alimentaria"'::jsonb),
  ('hero_subtitle',   '"Productos, insumos y herramientas para higiene, control, trazabilidad y buenas prácticas en la manipulación de alimentos."'::jsonb),
  ('hero_stats',      '[{"label":"Productos detectables","value":"200+"},{"label":"Aprobados FDA/UE","value":"FDA · UE"},{"label":"Cotización personalizada","value":"100%"}]'::jsonb),
  ('social_instagram','"https://www.instagram.com/seguridadalimentariapy"'::jsonb)
on conflict (key) do nothing;
