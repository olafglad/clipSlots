// Docs page: active section highlighting + mobile sidebar toggle.
(function () {
  "use strict";

  // ---- Mobile sidebar toggle --------------------------------------------
  const sidebar = document.querySelector("[data-docs-sidebar]");
  const toggle = document.querySelector("[data-docs-sidebar-toggle]");

  if (sidebar && toggle) {
    toggle.addEventListener("click", function () {
      sidebar.classList.toggle("open");
    });

    // Auto-close on link click (mobile)
    sidebar.querySelectorAll(".docs-nav-link").forEach(function (link) {
      link.addEventListener("click", function () {
        if (window.matchMedia("(max-width: 900px)").matches) {
          sidebar.classList.remove("open");
        }
      });
    });
  }

  // ---- Active section highlighting --------------------------------------
  const navLinks = Array.from(document.querySelectorAll(".docs-nav-link"));
  if (navLinks.length === 0) return;

  // Map of id -> nav link element
  const linkById = new Map();
  navLinks.forEach(function (link) {
    const href = link.getAttribute("href") || "";
    if (href.startsWith("#")) {
      linkById.set(href.slice(1), link);
    }
  });

  // Observe every docs-block (each command + each section subheading)
  const blocks = Array.from(document.querySelectorAll(".docs-block"));
  if (blocks.length === 0) return;

  // Track which blocks are currently in view; pick the topmost one.
  const visibleIds = new Set();

  function updateActive() {
    let topId = null;
    let topPosition = Infinity;
    visibleIds.forEach(function (id) {
      const el = document.getElementById(id);
      if (!el) return;
      const rect = el.getBoundingClientRect();
      if (rect.top < topPosition) {
        topPosition = rect.top;
        topId = id;
      }
    });

    navLinks.forEach(function (link) {
      link.classList.remove("active");
    });
    if (topId && linkById.has(topId)) {
      linkById.get(topId).classList.add("active");
    }
  }

  const observer = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          visibleIds.add(entry.target.id);
        } else {
          visibleIds.delete(entry.target.id);
        }
      });
      updateActive();
    },
    {
      // Activate when the block's top crosses 30% from the viewport top.
      rootMargin: "-96px 0px -65% 0px",
      threshold: 0,
    }
  );

  blocks.forEach(function (block) {
    if (block.id) observer.observe(block);
  });
})();
