/* Agency theme interactions: reveal on scroll, header state, mobile menu, form prefill. */
(function () {
  const root = document.documentElement;
  const designMode = window.Shopify && window.Shopify.designMode;

  /* Reveal on scroll ------------------------------------------------------ */
  function initReveal(scope) {
    const items = (scope || document).querySelectorAll('.ag-reveal:not(.is-visible)');
    if (!items.length) return;

    if (!root.classList.contains('ag-js') || designMode || !('IntersectionObserver' in window)) {
      items.forEach((el) => el.classList.add('is-visible'));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        });
      },
      { rootMargin: '0px 0px -8% 0px', threshold: 0.08 },
    );

    items.forEach((el) => observer.observe(el));
  }

  /* Header ---------------------------------------------------------------- */
  function initHeader() {
    const header = document.querySelector('[data-ag-header]');
    if (!header || header.dataset.agReady) return;
    header.dataset.agReady = 'true';

    const onScroll = () => header.classList.toggle('is-scrolled', window.scrollY > 8);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });

    const toggle = header.querySelector('[data-ag-menu-toggle]');
    const menu = document.getElementById('AgencyMobileMenu');
    if (!toggle || !menu) return;

    const setOpen = (open) => {
      if (open) {
        root.style.setProperty('--ag-header-bottom', `${Math.max(header.getBoundingClientRect().bottom, 0)}px`);
      }
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? toggle.dataset.labelClose : toggle.dataset.labelOpen);
      menu.classList.toggle('is-open', open);
      menu.toggleAttribute('inert', !open);
      document.body.classList.toggle('ag-menu-open', open);
    };

    setOpen(false);

    toggle.addEventListener('click', () => setOpen(toggle.getAttribute('aria-expanded') !== 'true'));

    menu.addEventListener('click', (event) => {
      if (event.target.closest('a')) setOpen(false);
    });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        setOpen(false);
        toggle.focus();
      }
    });

    window.matchMedia('(min-width: 990px)').addEventListener('change', (event) => {
      if (event.matches) setOpen(false);
    });
  }

  /* Contact form prefill: /pages/contact?service=...&package=... ---------- */
  function initPrefill() {
    const params = new URLSearchParams(window.location.search);

    document.querySelectorAll('[data-ag-prefill]').forEach((field) => {
      const value = params.get(field.dataset.agPrefill);
      if (!value) return;

      if (field.tagName === 'SELECT') {
        const match = Array.from(field.options).find((option) => option.value.toLowerCase() === value.toLowerCase());
        if (match) field.value = match.value;
      } else {
        field.value = value.slice(0, 120);
      }
    });
  }

  function init(scope) {
    initHeader();
    initReveal(scope);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
      init();
      initPrefill();
    });
  } else {
    init();
    initPrefill();
  }

  document.addEventListener('shopify:section:load', (event) => init(event.target));
})();
