// app/javascript/controllers/audio_player_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.globalAudioPlayer = document.getElementById("global-audio-player");
    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;

    if (this.globalAudioPlayer) {
      // Lier le 'this' pour que les gestionnaires d'événements fonctionnent correctement
      this.handleAudioEnd = this.handleAudioEnd.bind(this);
      this.globalAudioPlayer.addEventListener("ended", this.handleAudioEnd);
    } else {
      console.error("Le lecteur audio global (#global-audio-player) est introuvable.");
    }
  }

  disconnect() {
    // Nettoie l'écouteur d'événement quand le contrôleur est retiré de la page
    if (this.globalAudioPlayer) {
      this.globalAudioPlayer.removeEventListener("ended", this.handleAudioEnd);
    }
  }

  // Méthode pour réinitialiser l'état du bouton de lecture
  handleAudioEnd() {
    if (this.currentlyPlayingButton) {
      const icon = this.currentlyPlayingButton.querySelector("i");
      if (icon) {
        icon.classList.remove("bi-pause-fill", "bi-hourglass-split");
        icon.classList.add("bi-play-fill");
      }
    }
    if (this.currentVisualWrapper) {
      this.currentVisualWrapper.classList.remove("is-playing");
    }
    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;
  }

  // Méthode principale appelée lors du clic
  async togglePlay(event) {
    event.preventDefault();
    const clickedButton = event.currentTarget;
    const cell = clickedButton.closest(".carousel-cell");
    const trackId = cell.dataset.trackId;
    const visualWrapper = clickedButton.closest(".album-art-visual-wrapper");
    const icon = clickedButton.querySelector("i");

    if (!trackId) {
      console.warn("Attribut 'data-track-id' manquant sur l'élément .carousel-cell");
      return;
    }

    const isPlayingThisTrack = this.currentlyPlayingButton === clickedButton && !this.globalAudioPlayer.paused;

    // Si on clique sur le bouton du morceau en cours de lecture -> on met en pause
    if (isPlayingThisTrack) {
      this.globalAudioPlayer.pause();
      icon.classList.remove("bi-pause-fill");
      icon.classList.add("bi-play-fill");
      visualWrapper.classList.remove("is-playing");
      return;
    }

    // Si un autre morceau jouait, on le stoppe et on réinitialise son bouton
    if (this.currentlyPlayingButton) {
      this.handleAudioEnd();
    }

    // Met à jour les références actuelles
    this.currentlyPlayingButton = clickedButton;
    this.currentVisualWrapper = visualWrapper;

    // Affiche un indicateur de chargement
    icon.classList.remove("bi-play-fill", "bi-pause-fill");
    icon.classList.add("bi-hourglass-split");
    visualWrapper.classList.add("is-playing"); // Rend le bouton visible pendant le chargement

    // Fait l'appel à notre propre API pour obtenir une URL fraîche
    try {
      const response = await fetch(`/tracks/${trackId}/preview`);
      if (!response.ok) {
        throw new Error(`Erreur serveur : ${response.statusText}`);
      }
      const data = await response.json();

      if (data.preview_url) {
        this.globalAudioPlayer.src = data.preview_url;
        await this.globalAudioPlayer.play();
        // Le morceau joue, on met l'icône "pause"
        icon.classList.remove("bi-hourglass-split", "bi-play-fill");
        icon.classList.add("bi-pause-fill");
      } else {
        throw new Error("URL de prévisualisation non disponible.");
      }
    } catch (error) {
      console.error("Impossible de récupérer ou de jouer l'extrait :", error);
      this.handleAudioEnd(); // Réinitialise l'état en cas d'erreur
    }
  }
}
