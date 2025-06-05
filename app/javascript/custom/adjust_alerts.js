// app/javascript/custom/adjust_alerts.js

const adjustAlertsForNavbar = () => {
  const navbarBottom = document.querySelector('nav.bottom-navbar');
  const body = document.body;
  
  if (navbarBottom && window.innerWidth <= 768) { // Seulement sur mobile
    const navbarHeight = navbarBottom.offsetHeight;
    body.classList.add('with-bottom-navbar');
    document.documentElement.style.setProperty('--navbar-height', `${navbarHeight + 16}px`);
  } else {
    body.classList.remove('with-bottom-navbar');
  }
};

// Initial call
document.addEventListener('DOMContentLoaded', adjustAlertsForNavbar);

// Pour Turbo Drive/Turbolinks
document.addEventListener('turbo:load', adjustAlertsForNavbar);

// Pour les resize (au cas où)
window.addEventListener('resize', adjustAlertsForNavbar);

// Auto-dismissal for info flashes
document.addEventListener('DOMContentLoaded', function() {
  const autoDismissAlerts = document.querySelectorAll('.flash-message[data-auto-dismiss="true"]');
  
  autoDismissAlerts.forEach(alert => {
    setTimeout(() => {
      const bsAlert = new bootstrap.Alert(alert);
      bsAlert.close();
    }, 10000); // 10 secondes
  });
});

document.addEventListener('turbo:load', function() {
  // Le même code que ci-dessus
  const autoDismissAlerts = document.querySelectorAll('.flash-message[data-auto-dismiss="true"]');
  
  autoDismissAlerts.forEach(alert => {
    setTimeout(() => {
      const bsAlert = new bootstrap.Alert(alert);
      bsAlert.close();
    }, 10000); // 10 secondes
  });
});
