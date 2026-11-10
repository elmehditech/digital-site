# Web Agency — Shopify theme

A premium web development agency website built on [Shopify Dawn](https://github.com/Shopify/dawn) 16.1.1 (Online Store 2.0).
Dawn's storefront features (products, collections, cart, blog, search) are untouched and inherit the dark brand palette.

## Pages

| Page | Template | Create in Shopify admin |
| --- | --- | --- |
| Home | `templates/index.json` | — |
| Services | `templates/page.services.json` | Page with handle `services`, template **services** |
| Portfolio | `templates/page.portfolio.json` | Page with handle `portfolio`, template **portfolio** |
| About | `templates/page.about.json` | Page with handle `about`, template **about** |
| Pricing | `templates/page.pricing.json` | Page with handle `pricing`, template **pricing** |
| Contact | `templates/page.contact.json` | Page with handle `contact`, template **contact** |
| Project detail | `templates/metaobject/portfolio_project.json` | Optional, see Portfolio below |

## One-time store setup

1. **Pages** — Online Store › Pages: create the five pages above. Buttons in the templates link to `/pages/services`, `/pages/portfolio`, `/pages/about`, `/pages/pricing` and `/pages/contact`, so keep those handles (or update the links in the theme editor).
2. **Navigation** — Online Store › Navigation › *Main menu*: add Services, Portfolio, About, Pricing, Contact. The header and the first footer column read this menu; the second footer column reads the *Footer* menu.
3. **Brand** — Theme settings › Logo (logo image), › Colors, › Typography, › **Agency** (accent colour, card radius, WhatsApp number, contact email, fallback meta description).
4. **WhatsApp** — every WhatsApp button stays hidden until a number is entered in Theme settings › Agency. No number ships with the theme.
5. **Contact form** — uses Shopify's native contact form; submissions go to the store's sender email (Settings › Notifications).
6. **SEO** — set each page's title and meta description under *Search engine listing* in the admin. Pages without one use the fallback from Theme settings › Agency.
7. **Testimonials** — the homepage ships with clearly tagged demo placeholders. Replace the text and untick *This is a placeholder* on each block.

## Portfolio (metaobjects)

The *Agency portfolio* section reads entries of a metaobject and falls back to its own blocks (the sample layouts) until entries exist.

Settings › Custom data › Metaobjects › *Add definition*:

- Name `Portfolio project`, type `portfolio_project`
- Fields (keys must match):
  - `name` — Single line text
  - `industry` — Single line text
  - `description` — Multi-line text
  - `services` — Single line text, *List of values*
  - `image` — File (images)
  - `project_url` — URL (optional link to the live site)
- Optional: enable **Publish entries as web pages** to give each project its own page, rendered by `templates/metaobject/portfolio_project.json`. "View Project" then links to that page; otherwise it links to `project_url`.

Add entries under Content › Metaobjects. They appear on the homepage and the Portfolio page automatically.

## Theme structure (agency additions)

- `sections/agency-*.liquid` — header, footer, hero, page hero, marquee, cards, service list, portfolio, project, process, expertise, text & media, testimonials, FAQ, pricing, call to action, inquiry form. All have presets and can be added to any template in the theme editor.
- `snippets/agency-*.liquid` — section heading, icons, placeholder illustrations, WhatsApp button.
- `assets/agency.css`, `assets/agency.js` — design system and the small script for scroll reveals, the mobile menu and form prefill.
- Dawn's original header and footer sections remain available and can be re-added to the header/footer groups in the theme editor (for example if you need the cart drawer, predictive search or country selector).

## Commands

```sh
# from this folder (web-agency/)
shopify theme check                               # lint
shopify theme dev --store your-store.myshopify.com    # local preview
shopify theme push --unpublished --store your-store.myshopify.com   # upload as a new unpublished theme
```

`shopify theme push --unpublished` never publishes; review the theme in the admin first.
