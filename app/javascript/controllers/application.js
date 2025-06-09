import { Application } from "@hotwired/stimulus"
// import "bootstrap"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

export { application }

document.addEventListener('turbo:load', function() {
  // Fix pour les modales Bootstrap avec Turbo
  document.querySelectorAll('[data-bs-toggle="modal"]').forEach(button => {
    button.addEventListener('click', function() {
      const modal = new bootstrap.Modal(document.getElementById(this.dataset.bsTarget));
      modal.show();
    });
  });

  // Gestion des votes
  document.querySelectorAll('.btn-vote').forEach(function(button) {
    button.addEventListener('ajax:success', function(event) {
      let data = event.detail[0];
      let postId = data.post_id;
      let voteType = data.vote_type;

      let likeButton = document.getElementById(`like-button-${postId}`);
      let dislikeButton = document.getElementById(`dislike-button-${postId}`);

      if (voteType === 'hot') {
        likeButton.innerHTML = '<i class="bi bi-hand-thumbs-up-fill" style="color: green;"></i>';
        dislikeButton.innerHTML = '<i class="bi bi-hand-thumbs-down"></i>';
      } else if (voteType === 'cold') {
        likeButton.innerHTML = '<i class="bi bi-hand-thumbs-up"></i>';
        dislikeButton.innerHTML = '<i class="bi bi-hand-thumbs-down-fill" style="color: red;"></i>';
      }
    });
  });
});
