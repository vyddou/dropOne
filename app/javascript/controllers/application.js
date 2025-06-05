import { Application } from "@hotwired/stimulus"
// import "bootstrap"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

export { application }

document.addEventListener('turbo:load', function() {
  // Fix pour les modales Bootstrap avec Turbo
  document.querySelectorAll('[data-bs-toggle="modal"]').forEach(button => {
    button.addEventListener('click', function() {
      const modal = new bootstrap.Modal(document.getElementById(this.dataset.bsTarget));
      modal.show();
    });
  });
});
