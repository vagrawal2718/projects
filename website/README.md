# Vishakha Agrawal — Portfolio Website

A single-page personal portfolio website The site is static (HTML + CSS + vanilla JS) and is intended for
deployment to a university `public_html` directory — no build step, no npm, and no
server-side code. Third-party libraries are loaded from public CDNs.

Live: <https://students.iiit.ac.in/~vishakha.agrawal/>

---

## Sections

The site is one page (`index.html`) divided into anchored sections:

| Anchor | Section | Contents |
|---|---|---|
| `#hero` | Home | Name, tagline, intro text, résumé download, quick stats |
| `#about` | About | Short bio and quick-facts cards |
| `#education` | Education | IIIT-H, FIITJEE, and Prerana Waldorf School |
| `#skills` | Skills | Five categories (Languages, ML/DL, Web & Mobile, Geospatial, Systems) |
| `#projects` | Projects | 14 project cards with tech stacks, descriptions, and repo/demo links; category filter |
| `#publications` | Publications | arXiv preprint citation with links |
| `#contact` | Contact | Email, GitHub, LinkedIn, and résumé download |

Project descriptions are taken from the author's own project READMEs
(<https://github.com/vagrawal2718/projects>).

A JavaScript intro overlay plays on load and then reveals the page. It is gated behind a
`has-js` flag (so it is skipped when JavaScript is unavailable), respects
`prefers-reduced-motion`, and has a failsafe timeout that removes it if anything stalls.

---

## File structure

```
public_html/
├── index.html        # Markup for all sections
├── styles.css        # Styles, design tokens, and components
├── main.js           # Library init and interactions (nav, project filter, intro, parallax)
├── README.md         # This file
│
├── profile.png       # Portrait image (550×550)
├── iiit.jpeg         # Education logo — IIIT Hyderabad
├── fiitjee.png       # Education logo — FIITJEE
├── prerana.webp      # Education logo — Prerana Waldorf School
└── Resume.pdf        # Résumé (linked from nav, hero, and contact)
```

Everything else is loaded from CDNs at runtime.

---

## External libraries (all via CDN)

| Library | Version | Purpose | License |
|---|---|---|---|
| [Google Fonts](https://fonts.google.com/) — Fraunces, Inter | — | Typography | SIL OFL |
| [AOS](https://github.com/michalsnik/aos) | 2.3.4 | Scroll-reveal animations | MIT |
| [Typed.js](https://github.com/mattboldt/typed.js) | 2.1.0 | Hero typing animation | MIT |
| [GSAP](https://gsap.com/) + ScrollTrigger | 3.12.5 | Intro and reveal animations | Standard "No Charge" |
| [Lucide](https://lucide.dev/) | 0.544.0 | Icons | ISC |

These are also credited in an HTML comment at the top of `index.html` and `main.js`. No CSS
framework is used.

---

## Local preview

Because everything is static, serve the folder over HTTP (opening `index.html` via
`file://` also works, but a local server avoids CDN/CORS quirks):

```bash
cd public_html
python3 -m http.server 8000
# then open http://localhost:8000
```

---

## Deployment (university `public_html`)

1. Copy the contents of this folder into your server's `public_html` directory, e.g.:

   ```bash
   scp -r ./* vishakha.agrawal@<iiit-server>:~/public_html/
   ```

   (or use `rsync -avz ./ user@host:~/public_html/`)

2. Ensure files are world-readable so the web server can serve them:

   ```bash
   chmod 644 ~/public_html/*.html ~/public_html/*.css ~/public_html/*.js \
             ~/public_html/*.png ~/public_html/*.jpeg ~/public_html/*.webp ~/public_html/*.pdf
   chmod 755 ~/public_html
   ```

3. Visit your URL (e.g. `https://students.iiit.ac.in/~vishakha.agrawal/`).

`index.html` is the default document, so no extra configuration is needed. An internet
connection is required on the visitor's side for the CDN libraries and Google Fonts.

---


## Credits

Project content is sourced from the author's coursework repositories. Third-party libraries
are credited above.
