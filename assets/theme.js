(function () {
  // Mobile navigation
  var toggle = document.querySelector('[data-nav-toggle]');
  var nav = document.getElementById('SiteNav');
  function setNav(open) {
    if (!toggle || !nav) return;
    nav.classList.toggle('is-open', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    document.documentElement.style.overflow = open ? 'hidden' : '';
  }
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      setNav(!nav.classList.contains('is-open'));
    });
    nav.addEventListener('click', function (event) {
      if (event.target.closest('a')) setNav(false);
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && nav.classList.contains('is-open')) {
        setNav(false);
        toggle.focus();
      }
    });
    window.addEventListener('resize', function () {
      if (window.innerWidth >= 990) setNav(false);
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
    }, { rootMargin: '0px 0px -6% 0px' });
    items.forEach(function (el) { observer.observe(el); });
  }

  // Portfolio filters
  document.querySelectorAll('[data-portfolio]').forEach(function (section) {
    var buttons = section.querySelectorAll('[data-filter]');
    var projects = section.querySelectorAll('[data-category]');
    buttons.forEach(function (button) {
      button.addEventListener('click', function () {
        var filter = button.getAttribute('data-filter');
        buttons.forEach(function (b) {
          var active = b === button;
          b.classList.toggle('is-active', active);
          b.setAttribute('aria-pressed', active ? 'true' : 'false');
        });
        projects.forEach(function (project) {
          project.hidden = filter !== 'all' && project.getAttribute('data-category') !== filter;
          project.classList.add('is-visible');
        });
      });
    });
  });

  // Contact form: preselect the service from ?service=… and show the result message
  var params = new URLSearchParams(window.location.search);
  var wanted = (params.get('service') || '').toLowerCase();
  var select = document.querySelector('[data-service-select]');
  if (wanted && select) {
    Array.prototype.some.call(select.options, function (option) {
      if (option.value.toLowerCase().indexOf(wanted) === -1) return false;
      select.value = option.value;
      return true;
    });
  }
  var message = document.querySelector('[data-form-message]');
  if (message) {
    message.scrollIntoView({ block: 'center' });
    message.focus({ preventScroll: true });
  }
})();
