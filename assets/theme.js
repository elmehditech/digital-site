(function () {
  document.documentElement.classList.add('js');

  // Mobile navigation
  var toggle = document.querySelector('[data-nav-toggle]');
  var nav = document.getElementById('SiteNav');
  function closeNav() {
    if (!toggle || !nav) return;
    nav.classList.remove('is-open');
    toggle.setAttribute('aria-expanded', 'false');
  }
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('is-open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    nav.addEventListener('click', function (event) {
      if (event.target.closest('a')) closeNav();
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') closeNav();
    });
  }

  // Header border once the page is scrolled
  var header = document.querySelector('[data-header]');
  function onScroll() {
    if (header) header.classList.toggle('is-scrolled', window.scrollY > 8);
  }
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  // Reveal on scroll
  var items = document.querySelectorAll('.reveal');
  if (!('IntersectionObserver' in window)) {
    items.forEach(function (el) { el.classList.add('is-visible'); });
  } else {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { rootMargin: '0px 0px -8% 0px' });
    items.forEach(function (el) { observer.observe(el); });
  }

  // Pre-select the plan in the quote form when a pack button is clicked
  document.querySelectorAll('.pack').forEach(function (pack) {
    var link = pack.querySelector('a.button[href^="#"]');
    var title = pack.querySelector('.pack__title');
    var select = document.getElementById('DevisPlan');
    if (!link || !title || !select) return;
    link.addEventListener('click', function () {
      var key = title.textContent.trim().toLowerCase().split(' ')[0];
      Array.prototype.forEach.call(select.options, function (option) {
        if (option.value.toLowerCase().indexOf(key) !== -1) select.value = option.value;
      });
    });
  });
})();
