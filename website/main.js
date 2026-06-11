/* ============================================================================
   Vishakha Agrawal — Portfolio
   main.js : initialises CDN libraries and wires up site interactions.

   Libraries used (loaded via CDN in index.html):
     - Lucide   (icons)            https://lucide.dev/
     - AOS      (scroll reveal)    https://github.com/michalsnik/aos
     - Typed.js (hero typing)      https://github.com/mattboldt/typed.js
     - GSAP + ScrollTrigger        https://gsap.com/
   ========================================================================== */
(function () {
  "use strict";

  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const $  = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

  /* ---------------------------------------------------------- Icons (Lucide) */
  function renderIcons() {
    if (window.lucide && typeof window.lucide.createIcons === "function") {
      window.lucide.createIcons();
    }
  }

  /* --------------------------------------------------------------- Footer yr */
  function setYear() {
    const el = $("#year");
    if (el) el.textContent = new Date().getFullYear();
  }

  /* ----------------------------------------------------------------- Navbar */
  function initNav() {
    const nav = $("#nav");
    const links = $("#navLinks");
    const toggle = $("#navToggle");
    const backdrop = $("#navBackdrop");

    // Shrink / frost on scroll
    const onScroll = () => {
      if (window.scrollY > 24) nav.classList.add("scrolled");
      else nav.classList.remove("scrolled");
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });

    // Mobile menu
    const closeMenu = () => {
      links.classList.remove("open");
      backdrop.classList.remove("show");
      toggle.setAttribute("aria-expanded", "false");
      toggle.setAttribute("aria-label", "Open menu");
    };
    const openMenu = () => {
      links.classList.add("open");
      backdrop.classList.add("show");
      toggle.setAttribute("aria-expanded", "true");
      toggle.setAttribute("aria-label", "Close menu");
    };
    toggle.addEventListener("click", () =>
      links.classList.contains("open") ? closeMenu() : openMenu()
    );
    backdrop.addEventListener("click", closeMenu);
    $$(".nav__link, .nav__cta", links).forEach((a) =>
      a.addEventListener("click", closeMenu)
    );
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") closeMenu();
    });
  }

  /* ---------------------------------------------- Scroll-spy (active links) */
  function initScrollSpy() {
    const sections = $$("section[id], header[id]").filter((s) =>
      $(`.nav__link[href="#${s.id}"]`)
    );
    const linkFor = (id) => $(`.nav__link[href="#${id}"]`);
    if (!("IntersectionObserver" in window) || !sections.length) return;

    const obs = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) {
            $$(".nav__link").forEach((l) => l.classList.remove("active"));
            const link = linkFor(e.target.id);
            if (link) link.classList.add("active");
          }
        });
      },
      { rootMargin: "-45% 0px -50% 0px", threshold: 0 }
    );
    sections.forEach((s) => obs.observe(s));
  }

  /* ------------------------------------------------------------- Back to top */
  function initBackToTop() {
    const btn = $("#toTop");
    if (!btn) return;
    const onScroll = () => btn.classList.toggle("show", window.scrollY > 700);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ------------------------------------------------------------- Typed hero */
  function initTyped() {
    const el = $("#typed");
    if (!el || typeof window.Typed === "undefined") return;
    if (prefersReduced) {
      el.textContent = "Computer Science @ IIIT Hyderabad";
      return;
    }
    new window.Typed("#typed", {
      strings: [
        "Computer Science @ IIIT Hyderabad",
        "Let's explore.",
        "Let's innovate.",
        "Let's create — together.",
      ],
      typeSpeed: 55,
      backSpeed: 28,
      backDelay: 1700,
      startDelay: 400,
      loop: true,
      smartBackspace: true,
    });
  }

  /* ----------------------------------------------------- Project filtering */
  function initProjectFilter() {
    const filter = $("#projFilter");
    const cards = $$(".proj-card");
    if (!filter) return;

    filter.addEventListener("click", (e) => {
      const btn = e.target.closest(".filter-btn");
      if (!btn) return;
      $$(".filter-btn", filter).forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");

      const f = btn.dataset.filter;
      cards.forEach((card) => {
        const cats = (card.dataset.cat || "").split(/\s+/);
        const show = f === "all" || cats.includes(f);
        card.classList.toggle("is-hidden", !show);
      });

      // Re-pulse a subtle entrance on the now-visible cards
      if (!prefersReduced && window.gsap) {
        const visible = cards.filter((c) => !c.classList.contains("is-hidden"));
        window.gsap.fromTo(
          visible,
          { y: 16, opacity: 0.001 },
          { y: 0, opacity: 1, duration: 0.5, stagger: 0.04, ease: "power2.out", overwrite: true }
        );
      }
      if (window.ScrollTrigger) window.ScrollTrigger.refresh();
    });

    // Pointer-tracked glow on cards
    cards.forEach((card) => {
      card.addEventListener("pointermove", (e) => {
        const r = card.getBoundingClientRect();
        card.style.setProperty("--mx", `${e.clientX - r.left}px`);
        card.style.setProperty("--my", `${e.clientY - r.top}px`);
      });
    });
  }

  /* ------------------------------------------- Interactive hero parallax */
  function initHeroParallax() {
    const fine = window.matchMedia("(pointer: fine)").matches;
    if (prefersReduced || !fine) return;
    const hero = $(".hero");
    const bg = $(".hero__bg");
    const portrait = $(".portrait-frame");
    if (!hero) return;

    hero.addEventListener("pointermove", (e) => {
      const r = hero.getBoundingClientRect();
      const dx = (e.clientX - r.left) / r.width - 0.5;
      const dy = (e.clientY - r.top) / r.height - 0.5;
      if (bg) bg.style.transform = `translate(${dx * 22}px, ${dy * 22}px)`;
      if (portrait) portrait.style.transform = `rotate(2.5deg) translate(${dx * 16}px, ${dy * 16}px)`;
    });
    hero.addEventListener("pointerleave", () => {
      if (bg) bg.style.transform = "";
      if (portrait) portrait.style.transform = "";
    });
  }

  /* ------------------------------------ Intro background: twisting geometry */
  // A vortex of nested, irregular polygons that rotate and twist on a canvas.
  // The whole curtain later zooms *into* this formation to reveal the site.
  // Returns a stop() that halts the animation loop.
  function startIntroFormation(canvas, reduced) {
    const ctx = canvas && canvas.getContext && canvas.getContext("2d");
    if (!ctx) return function () {};
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    let raf = 0;
    let running = !reduced;
    let t = 0;

    const size = () => {
      canvas.width = Math.max(1, Math.floor(canvas.clientWidth * dpr));
      canvas.height = Math.max(1, Math.floor(canvas.clientHeight * dpr));
    };
    size();
    window.addEventListener("resize", size);

    const RINGS = 13;   // total rings in the vortex
    const INNER = 6;    // first ring drawn — leaves a clear "well" for the name

    const render = () => {
      const W = canvas.width, H = canvas.height;
      const cx = W / 2, cy = H / 2;
      const baseR = Math.min(W, H) * 0.42;
      ctx.clearRect(0, 0, W, H);

      // Nested polygons forming a twisting halo — sides, spin direction and speed
      // vary per ring, with a per-vertex "breathing" jitter so the formation reads
      // as irregular. The innermost rings are skipped so the name sits in a clear well.
      for (let i = INNER; i <= RINGS; i++) {
        const f = i / RINGS;
        const radius = baseR * f;
        const sides = 3 + ((i * 2) % 6);
        const dir = i % 2 ? 1 : -1;
        const rot = t * (0.16 + f * 0.14) * dir + i * 0.5;
        ctx.beginPath();
        for (let s = 0; s <= sides; s++) {
          const a = rot + (s / sides) * Math.PI * 2;
          const jr = radius * (1 + 0.08 * Math.sin(a * 3 + t * 1.1 + i));
          const x = cx + Math.cos(a) * jr;
          const y = cy + Math.sin(a) * jr;
          if (s === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.closePath();
        const teal = i % 3 === 0;
        const alpha = 0.5 - (f - INNER / RINGS) * 0.3; // brighter near the centre well
        ctx.lineWidth = (2.8 - f * 1.0) * dpr;
        ctx.strokeStyle = teal
          ? "rgba(94,224,212," + alpha + ")"   // teal accent rings
          : "rgba(255,255,255," + alpha + ")";
        ctx.shadowColor = teal ? "rgba(94,224,212,0.5)" : "rgba(255,255,255,0.3)";
        ctx.shadowBlur = 7 * dpr;
        ctx.stroke();
        ctx.shadowBlur = 0;
      }
    };

    const loop = () => {
      render();
      t += 0.016;
      if (running) raf = requestAnimationFrame(loop);
    };
    if (running) loop(); else render();

    return function stop() {
      running = false;
      if (raf) cancelAnimationFrame(raf);
      window.removeEventListener("resize", size);
    };
  }

  /* ------------------------------------------------ Intro / welcome curtain */
  function initIntro() {
    const intro = $("#intro");
    if (!intro) return; // no-js path: CSS keeps it hidden
    const root = document.documentElement;
    root.classList.add("intro-active");

    const stop = startIntroFormation($("#introCanvas"), prefersReduced);

    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      stop();
      root.classList.remove("intro-active");
      if (intro.parentNode) intro.parentNode.removeChild(intro);
      if (window.ScrollTrigger) window.ScrollTrigger.refresh();
    };
    // Hard failsafe — never trap the visitor behind the curtain.
    setTimeout(finish, 6000);

    if (prefersReduced || !window.gsap) {
      intro.style.transition = "opacity .4s ease";
      intro.style.opacity = "0";
      setTimeout(finish, prefersReduced ? 0 : 450);
      return;
    }

    const g = window.gsap;
    g.timeline({ onComplete: finish, defaults: { ease: "power2.out" } })
      // 1. Name + tagline rise in.
      .from(".intro__name", { y: 20, opacity: 0, duration: 0.6 })
      .from(".intro__tag", { y: 12, opacity: 0, duration: 0.5 }, "-=0.35")
      // 2. The geometric halo forms around them (scale/rotate only — kept fully
      //    opaque so the formation is always clearly drawn).
      .from("#introCanvas", { scale: 0.5, rotation: -16, duration: 1.25, ease: "power2.out", transformOrigin: "50% 50%" }, "-=0.5")
      // 3. Brief hold so the formation can be read.
      .to({}, { duration: 0.5 })
      // 4. Fly *into* the formation — the whole curtain zooms up and dissolves...
      .to("#intro", { scale: 7.5, opacity: 0, duration: 1.0, ease: "power3.in", transformOrigin: "50% 50%" })
      // 5. ...and the site settles in behind it.
      .fromTo("#hero", { scale: 1.06 }, { scale: 1, duration: 1.05, ease: "power3.out", clearProps: "transform" }, "<");
  }

  /* ------------------------------------------------------------------ Boot */
  function boot() {
    renderIcons();
    setYear();
    initIntro();
    initNav();
    initScrollSpy();
    initBackToTop();
    initTyped();
    initProjectFilter();
    initHeroParallax();

    if (window.AOS) {
      window.AOS.init({
        duration: 720,
        easing: "ease-out-cubic",
        once: true,
        offset: 60,
        disable: prefersReduced,
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
