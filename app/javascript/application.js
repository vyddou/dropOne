// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "channels"
import "@popperjs/core"
import "bootstrap"


document.addEventListener('turbo:load', () => {
  const input = document.getElementById('search-input');
  const form = document.getElementById('search-form');

  if (!input || !form) return;  // Quitte si un des éléments est introuvable

  input.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault(); // empêche le comportement par défaut (si besoin)
      form.requestSubmit();    // déclenche l'envoi du formulaire comme si tu cliquais sur le bouton
    }
  });
});
