# Seguridad Alimentaria PY — Handoff técnico

Este paquete contiene:

1. `Seguridad Alimentaria PY.dc.html` — Prototipo de alta fidelidad, todas las pantallas navegables.
2. `supabase/schema.sql` — Schema completo de Supabase (tablas, RLS, storage, seed).
3. `assets/logo.png`, `assets/isotype.png` — Logo oficial y monograma extraídos del manual de marca.

El **prototipo HTML no es la app final** — es la especificación visual pixel-perfect. El desarrollo real se hace en un proyecto **Next.js** conectado a **Supabase self-host**. Este documento explica cómo hacerlo.

---

## 1 · Sistema visual · resumen

| Token | Valor | Uso |
|-|-|-|
| `--sa-white` | `#FFFFFF` | Fondos principales |
| `--sa-ink` | `#0E1712` | Texto principal, bloques oscuros |
| `--sa-green-primary` | `#3DAB38` | Verde sanitario · CTAs, WhatsApp, acentos positivos |
| `--sa-green-dark` | `#2E8A2C` | Hover verde |
| `--sa-green-light` | `#8DBF28` | Marca secundaria del manual |
| `--sa-blue` | `#1E5FA8` | Azul técnico · badges "Detectable", categorías |
| `--sa-orange` | `#F19100` | Naranja acento del logo · alertas suaves |
| `--sa-yellow` | `#B77A00` | Amarillo acento · badges "FDA · UE" |
| `--sa-gray-50` | `#F5F7F2` | Superficies suaves |
| `--sa-gray-100` | `#E3E7E1` | Bordes |
| `--sa-gray-500` | `#78827B` | Texto secundario |
| `--sa-gray-700` | `#4A5348` | Texto de párrafo |

**Tipografías:**
- `Montserrat` (400 · 500 · 600 · 700 · 800 · 900) — titulares & UI
- `JetBrains Mono` (400 · 500 · 600) — SKUs, códigos, eyebrows técnicos

Cargar desde Google Fonts (ya está en el prototipo).

**Motivos de marca del manual aplicados:**
- Curvas verdes decorativas (SVG en secciones oscuras)
- Punto naranja del isotipo como acento
- Eyebrow con guión "— 01 · Sección"
- Badges técnicos con fondo pastel + texto oscuro

---

## 2 · Stack recomendado

```
Next.js 14 (App Router) + TypeScript
├─ @supabase/ssr           · cliente Supabase server-side
├─ @supabase/supabase-js   · cliente browser
├─ tailwindcss             · con los tokens de arriba en tailwind.config.ts
├─ lucide-react            · iconos
└─ zod                     · validación de formularios
```

Deploy: Vercel para el frontend, Supabase self-host (tu instancia) para backend.

---

## 3 · Variables de entorno

`.env.local` (NO commitear):

```bash
# Público — usable en cliente
NEXT_PUBLIC_SUPABASE_URL=https://supabase.tudominio.com
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbG...

# Sólo servidor — nunca exponer
SUPABASE_SERVICE_ROLE_KEY=eyJhbG...

# Extras
NEXT_PUBLIC_WHATSAPP_NUMBER=595982296371
NEXT_PUBLIC_SITE_URL=https://laseguridadalimentaria.com
```

---

## 4 · Instalación del schema

1. Crear proyecto en tu Supabase self-host.
2. Abrir SQL editor → pegar `supabase/schema.sql` → run.
3. Verificar buckets `product-images` y `brand-assets` en Storage.
4. Crear el usuario admin desde Auth y setear rol:

```sql
update auth.users
   set raw_app_meta_data = raw_app_meta_data || '{"role":"admin"}'::jsonb
 where email = 'admin@laseguridadalimentaria.com';
```

El helper `seguridadalimentaria.is_admin()` lee ese claim en todas las policies.

---

## 5 · Estructura de carpetas sugerida

```
app/
├─ (public)/
│  ├─ page.tsx                          · Home
│  ├─ productos/
│  │  ├─ page.tsx                       · Catálogo con filtros
│  │  └─ [slug]/page.tsx                · Detalle de producto
│  ├─ categorias/
│  │  ├─ page.tsx                       · Overview de categorías
│  │  └─ [slug]/page.tsx                · Productos de una categoría
│  ├─ nosotros/page.tsx
│  ├─ seguridad-alimentaria/page.tsx
│  ├─ contacto/page.tsx
│  └─ layout.tsx                        · Header + footer + CartDrawer
├─ (admin)/
│  └─ admin/
│     ├─ login/page.tsx
│     ├─ layout.tsx                     · Sidebar + guard
│     ├─ page.tsx                       · Dashboard KPIs
│     ├─ productos/{,new,[id]}/page.tsx
│     ├─ categorias/{,new,[id]}/page.tsx
│     ├─ pedidos/{,[id]}/page.tsx
│     ├─ contactos/page.tsx
│     └─ settings/page.tsx
├─ api/
│  ├─ orders/route.ts                   · POST público: crea order + items
│  ├─ contact/route.ts                  · POST público: crea contact_request
│  └─ upload/route.ts                   · POST admin: sube a Storage
components/
├─ shell/{Header,Footer,CartDrawer}.tsx
├─ home/{Hero,Categories,Featured,WhyUs,SafetyPillars,FinalCta}.tsx
├─ catalog/{FilterSidebar,ProductGrid,ProductCard}.tsx
├─ product/{Gallery,Info,Related}.tsx
├─ admin/{Sidebar,DataTable,ProductForm,OrderDetail}.tsx
└─ ui/{Button,Badge,Input,Select}.tsx
lib/
├─ supabase/{server,client,middleware}.ts
├─ whatsapp.ts                          · buildWhatsAppMessage(cart, customer)
├─ types.ts                             · tipos DB generados
└─ store/cart.ts                        · zustand · persist en localStorage
public/
├─ logo.png                             · copiar desde assets/logo.png
└─ favicon.ico
```

---

## 6 · Helper WhatsApp

```ts
// lib/whatsapp.ts
export function buildWhatsAppMessage(
  items: { name: string; quantity: number }[],
  customer: { name?: string; company?: string; city?: string; notes?: string }
) {
  const lines = ['Hola, quiero solicitar una cotización de Seguridad Alimentaria PY:'];
  items.forEach(i => lines.push(`• ${i.name} x ${i.quantity}`));
  lines.push('', `Nombre: ${customer.name ?? ''}`);
  lines.push(`Empresa: ${customer.company ?? ''}`);
  lines.push(`Ciudad: ${customer.city ?? ''}`);
  lines.push(`Observaciones: ${customer.notes ?? ''}`);
  return lines.join('\n');
}

export function openWhatsApp(message: string, phone = process.env.NEXT_PUBLIC_WHATSAPP_NUMBER!) {
  window.open(`https://wa.me/${phone}?text=${encodeURIComponent(message)}`, '_blank');
}
```

El endpoint `/api/orders` recibe el checkout, inserta `orders` + `order_items` con status `pendiente`, devuelve el order id — y el cliente abre WhatsApp en paralelo.

---

## 7 · Auth guard del admin

```ts
// app/(admin)/admin/layout.tsx
import { createServerSupabase } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';

export default async function AdminLayout({ children }) {
  const supabase = createServerSupabase();
  const { data: { user } } = await supabase.auth.getUser();
  const role = user?.app_metadata?.role;
  if (!user || role !== 'admin') redirect('/admin/login');
  return <AdminShell>{children}</AdminShell>;
}
```

---

## 8 · SEO

Meta tags principales están en el `<helmet>` del prototipo. Palabras clave:
`seguridad alimentaria Paraguay`, `productos detectables`, `cintillos de seguridad`, `packaging gastronómico`, `higiene alimentaria`, `HACCP`, `ISO`, `BRCGS`, `inocuidad`.

Generar sitemap con `next-sitemap` incluyendo un `<url>` por producto y categoría activos.

---

## 9 · Assets

- `assets/logo.png` — logo completo (mark + wordmark + tagline) sobre blanco
- `assets/isotype.png` — sólo el isotipo (hojas + punto), útil para header/favicon

Copiar ambos a `public/` en el proyecto Next.js.

Cuando el cliente entregue las fotos reales de producto, subirlas a Storage bucket `product-images/{product-slug}/01.webp, 02.webp, …` y guardar la URL pública en `product_images.image_url`.

---

## 10 · Qué NO está incluido (por instrucción)

- Pasarela de pago online
- Módulo de facturación electrónica
- Delivery / tracking avanzado
- ERP / stock complejo (el `stock` en `products` es informativo)

Estos quedan para fases futuras.

---

**Contacto de diseño:** el prototipo `Seguridad Alimentaria PY.dc.html` es la fuente de verdad visual. Cualquier decisión de estilo, spacing, o copy debe seguirlo.
