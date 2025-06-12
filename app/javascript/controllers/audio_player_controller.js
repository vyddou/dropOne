// app/javascript/controllers/audio_player_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // On s'assure qu'il n'y a qu'un seul lecteur global
    if (!document.getElementById("global-audio-player")) {
      const audio = document.createElement("audio");
      audio.id = "global-audio-player";
      document.body.appendChild(audio);
    }
    this.globalAudioPlayer = document.getElementById("global-audio-player");

    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;

    // Lier le 'this' pour que les gestionnaires d'événements fonctionnent
    this.handleAudioEnd = this.handleAudioEnd.bind(this);
    this.handleAudioPause = this.handleAudioPause.bind(this);
    this.globalAudioPlayer.addEventListener("ended", this.handleAudioEnd);
    this.globalAudioPlayer.addEventListener("pause", this.handleAudioPause);
  }

  disconnect() {
    if (this.globalAudioPlayer) {
      this.globalAudioPlayer.removeEventListener("ended", this.handleAudioEnd);
      this.globalAudioPlayer.removeEventListener("pause", this.handleAudioPause);
    }
  }

  // Gère la fin de la lecture ET la pause manuelle
  handleAudioStateChange() {
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

  handleAudioEnd() {
    this.handleAudioStateChange();
  }

  handleAudioPause() {
    // Évite de réinitialiser si la pause est gérée par notre propre code
    if (this.globalAudioPlayer.paused) {
      this.handleAudioStateChange();
    }
  }

  async togglePlay(event) {
    event.preventDefault();
    const clickedButton = event.currentTarget;
    const dataContainer = clickedButton.closest("[data-track-id], [data-preview-url]");
    const visualWrapper = clickedButton.closest(".album-art-visual-wrapper");
    const icon = clickedButton.querySelector("i");

    if (!dataContainer) return;

    const trackId = dataContainer.dataset.trackId;
    const previewUrl = dataContainer.dataset.previewUrl;

    // Détermine si on clique sur le bouton du morceau en cours de lecture
    // On compare soit la source actuelle, soit le bouton lui-même.
    const isPlayingThisTrack = (this.globalAudioPlayer.currentSrc === previewUrl || this.currentlyPlayingButton === clickedButton) && !this.globalAudioPlayer.paused;

    if (isPlayingThisTrack) {
      this.globalAudioPlayer.pause();
      return;
    }

    // Arrête tout autre morceau qui jouait
    if (this.currentlyPlayingButton) {
      this.handleAudioStateChange();
    }

    this.currentlyPlayingButton = clickedButton;
    this.currentVisualWrapper = visualWrapper;

    icon.classList.remove("bi-play-fill");
    icon.classList.add("bi-hourglass-split");
    visualWrapper.classList.add("is-playing");

    let urlToPlay;

    // Logique pour obtenir l'URL à jouer
    if (trackId) { // Cas #1 : On a un ID de notre base de données
      try {
        const response = await fetch(`/tracks/${trackId}/preview`);
        if (!response.ok) throw new Error("Preview non trouvée sur le serveur");
        const data = await response.json();
        urlToPlay = data.preview_url;
      } catch (error) {
        console.error("Impossible de récupérer l'extrait via API:", error);
        this.handleAudioStateChange();
        return;
      }
    } else if (previewUrl) { // Cas #2 : On a une URL directe (page de recherche)
      urlToPlay = previewUrl;
    }

    // Joue le morceau si on a une URL
    if (urlToPlay) {
      this.globalAudioPlayer.src = urlToPlay;
      this.globalAudioPlayer.play()
        .then(() => {
          icon.classList.remove("bi-hourglass-split", "bi-play-fill");
          icon.classList.add("bi-pause-fill");
        })
        .catch(error => {
          console.error("Erreur de lecture audio:", error);
          this.handleAudioStateChange();
        });
    } else {
      console.warn("Aucune source audio trouvée.");
      this.handleAudioStateChange();
    }
  }
}
