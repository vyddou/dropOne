// app/javascript/controllers/audio_player_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.globalAudioPlayer = document.getElementById("global-audio-player");
    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;

    if (this.globalAudioPlayer) {
      this.handleAudioEnd = this.handleAudioEnd.bind(this);
      this.globalAudioPlayer.addEventListener("ended", this.handleAudioEnd);
    }
  }

  disconnect() {
    if (this.globalAudioPlayer) {
      this.globalAudioPlayer.removeEventListener("ended", this.handleAudioEnd);
    }
  }

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

  async togglePlay(event) {
    event.preventDefault();
    const clickedButton = event.currentTarget;
    // --- MODIFICATION ICI : On cherche le conteneur qui a le data-track-id ---
    const cardContainer = clickedButton.closest("[data-track-id]");
    const trackId = cardContainer ? cardContainer.dataset.trackId : null;

    const visualWrapper = clickedButton.closest(".album-art-visual-wrapper");
    const icon = clickedButton.querySelector("i");

    if (!trackId) {
      console.warn("Attribut 'data-track-id' manquant sur un élément parent.");
      return;
    }

    const isPlayingThisTrack = this.currentlyPlayingButton === clickedButton && !this.globalAudioPlayer.paused;

    if (isPlayingThisTrack) {
      this.globalAudioPlayer.pause();
      icon.classList.remove("bi-pause-fill");
      icon.classList.add("bi-play-fill");
      visualWrapper.classList.remove("is-playing");
      return;
    }

    if (this.currentlyPlayingButton) {
      this.handleAudioEnd();
    }

    this.currentlyPlayingButton = clickedButton;
    this.currentVisualWrapper = visualWrapper;

    icon.classList.remove("bi-play-fill", "bi-pause-fill");
    icon.classList.add("bi-hourglass-split");
    visualWrapper.classList.add("is-playing");

    try {
      const response = await fetch(`/tracks/${trackId}/preview`);
      if (!response.ok) {
        throw new Error(`Erreur serveur : ${response.statusText}`);
      }
      const data = await response.json();

      if (data.preview_url) {
        this.globalAudioPlayer.src = data.preview_url;
        await this.globalAudioPlayer.play();
        icon.classList.remove("bi-hourglass-split", "bi-play-fill");
        icon.classList.add("bi-pause-fill");
      } else {
        throw new Error("URL de prévisualisation non disponible.");
      }
    } catch (error) {
      console.error("Impossible de récupérer ou de jouer l'extrait :", error);
      this.handleAudioEnd();
    }
  }
}
