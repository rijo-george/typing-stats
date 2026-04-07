// ── Scroll-reveal animation ───────────────────────────────────────
const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('revealed');
    }
  });
}, { threshold: 0.1 });

document.querySelectorAll('.feature-card, .buddy-card, .step, .buddy-demo, .download-card').forEach(el => {
  el.style.opacity = '0';
  el.style.transform = 'translateY(20px)';
  el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
  observer.observe(el);
});

// Stagger children within a grid
document.querySelectorAll('.features-grid, .buddy-grid, .steps').forEach(grid => {
  const children = grid.children;
  Array.from(children).forEach((child, i) => {
    child.style.transitionDelay = (i * 0.06) + 's';
  });
});

// Add class for revealed state
const style = document.createElement('style');
style.textContent = '.revealed { opacity: 1 !important; transform: translateY(0) !important; }';
document.head.appendChild(style);

// ── Smooth nav background on scroll ───────────────────────────────
const nav = document.querySelector('.nav');
window.addEventListener('scroll', () => {
  if (window.scrollY > 50) {
    nav.style.borderBottomColor = 'rgba(34, 34, 64, 0.8)';
  } else {
    nav.style.borderBottomColor = 'var(--border)';
  }
});

// ── Buddy card click — visual selection ───────────────────────────
document.querySelectorAll('.buddy-card').forEach(card => {
  card.addEventListener('click', () => {
    document.querySelectorAll('.buddy-card').forEach(c => c.classList.remove('buddy-card-active'));
    card.classList.add('buddy-card-active');

    // Update the demo character
    const emoji = card.querySelector('.buddy-emoji').textContent;
    const demoChar = document.querySelector('.buddy-demo-char');
    if (demoChar) {
      demoChar.textContent = emoji;
    }
  });
});

// ── Animate chart bars on scroll ──────────────────────────────────
const chartObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      const bars = entry.target.querySelectorAll('.mock-bar');
      bars.forEach((bar, i) => {
        const height = bar.style.height;
        bar.style.height = '2%';
        setTimeout(() => {
          bar.style.height = height;
        }, i * 30);
      });
      chartObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.3 });

const chartEl = document.querySelector('.mock-chart-bars');
if (chartEl) {
  chartObserver.observe(chartEl);
}
