# Seguridad Alimentaria PY

Sitio web estático de Seguridad Alimentaria PY — catálogo de productos detectables por metales y rayos X para industria alimentaria y farmacéutica.

## Cómo abrirlo

**Local**: abrí `index.html` con doble click (funciona con `file://`).

**Servidor**: cualquier hosting estático (Netlify, Vercel, GitHub Pages, Nginx). Recomendado servir con un HTTP server para que las rutas hash funcionen de forma consistente:

```bash
npx serve -l 5173 .
```

Después abrí `http://localhost:5173`.

## Rutas

- `/` — home
- `#/catalogo` — catálogo con filtros
- `#/producto/:id` — ficha de producto
- `#/categorias` — overview de categorías
- `#/nosotros` — nosotros
- `#/seguridad` — pilares de seguridad alimentaria
- `#/contacto` — formulario de contacto
- `#/admin` — panel de administración (login: `admin@laseguridadalimentaria.com` / `admin`)

## Estructura

- `index.html` — sitio completo, vanilla HTML+JS+CSS
- `assets/` — logo e isotipo
- `uploads/` — imágenes de productos y del sitio
- `supabase/` — schema SQL para el backend futuro
- `HANDOFF.md` — guía para migrar a Next.js + Supabase
- `Seguridad Alimentaria PY.dc.html` — prototipo de diseño original (referencia visual)
