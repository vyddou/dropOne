import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "playButtonIcon", "visualWrapper" ]

  connect() {
    console.log("Audio Player Controller connecté!", this.element)
    this.globalAudioPlayer = document.getElementById("global-audio-player");
    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;

    if (this.globalAudioPlayer) {
      this._setupGlobalPlayerListeners();
    }
  }

  _setupGlobalPlayerListeners() {
    this.handleAudioEnd = this.handleAudioEnd.bind(this);
    this.handleAudioError = this.handleAudioError.bind(this);

    this.globalAudioPlayer.addEventListener("ended", this.handleAudioEnd);
    this.globalAudioPlayer.addEventListener("error", this.handleAudioError);
  }

  handleAudioEnd() {
    if (this.currentlyPlayingButton) {
      const icon = this.currentlyPlayingButton.querySelector("i");
      icon.classList.remove("bi-pause-fill");
      icon.classList.add("bi-play-fill");
    }
    if (this.currentVisualWrapper) {
      this.currentVisualWrapper.classList.remove("is-playing");
    }
    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;
  }

  handleAudioError(e) {
    console.error("Erreur de lecture audio:", e);
    this.handleAudioEnd();
  }

  async togglePlay(event) {
    const clickedButton = event.currentTarget;
    const icon = clickedButton.querySelector("i");
    
    // On cherche le conteneur qui a les données. Peut être .carousel-cell ou .album-art-visual-wrapper
    const dataWrapper = clickedButton.closest("[data-track-id], [data-preview-url]");

    if (!dataWrapper) {
      console.warn("Aucun conteneur de données trouvé pour le lecteur audio.");
      return;
    }

    const trackId = dataWrapper.dataset.trackId;
    const previewUrl = dataWrapper.dataset.previewUrl;

    // Si on clique sur le bouton qui est déjà en lecture, on met en pause.
    if (this.currentlyPlayingButton === clickedButton && !this.globalAudioPlayer.paused) {
      this.globalAudioPlayer.pause();
      return;
    }

    // Si un autre bouton est cliqué, on réinitialise l'ancien.
    if (this.currentlyPlayingButton && this.currentlyPlayingButton !== clickedButton) {
      this.handleAudioEnd();
    }

    if (trackId) {
      // --- NOUVELLE LOGIQUE API ---
      await this.playViaApi(trackId, clickedButton, icon, dataWrapper);
    } else if (previewUrl) {
      // --- ANCIENNE LOGIQUE (FALLBACK) ---
      this.playDirectUrl(previewUrl, clickedButton, icon, dataWrapper);
    } else {
      console.warn("Aucune source audio (trackId ou previewUrl) disponible.");
    }
  }

  async playViaApi(trackId, button, icon, wrapper) {
    icon.classList.remove("bi-play-fill", "bi-pause-fill");
    icon.classList.add("bi-hourglass-split");

    try {
      const response = await fetch(`/tracks/${trackId}/preview`);
      if (!response.ok) throw new Error(`Erreur serveur: ${response.statusText}`);
      
      const data = await response.json();
      const freshUrl = data.preview_url;

      if (!freshUrl) {
        console.warn("Aucune URL d'extrait disponible pour ce morceau depuis Deezer.");
        this.handleAudioEnd();
        icon.classList.add("bi-play-fill");
        icon.classList.remove("bi-hourglass-split");
        return;
      }

      this.globalAudioPlayer.src = freshUrl;
      await this.globalAudioPlayer.play();

      icon.classList.remove("bi-hourglass-split", "bi-play-fill");
      icon.classList.add("bi-pause-fill");
      wrapper.classList.add("is-playing");

      this.currentlyPlayingButton = button;
      this.currentVisualWrapper = wrapper;

    } catch (error) {
      console.error("Impossible de récupérer ou de jouer l'extrait via API :", error);
      this.handleAudioEnd();
      icon.classList.add("bi-play-fill");
      icon.classList.remove("bi-hourglass-split");
    }
  }

  playDirectUrl(url, button, icon, wrapper) {
    if (this.globalAudioPlayer.src !== url) {
      this.globalAudioPlayer.src = url;
    }
    
    this.globalAudioPlayer.play().then(() => {
      icon.classList.remove("bi-play-fill");
      icon.classList.add("bi-pause-fill");
      wrapper.classList.add("is-playing");
      this.currentlyPlayingButton = button;
      this.currentVisualWrapper = wrapper;
    }).catch(error => {
      console.error("Erreur lors de la tentative de lecture directe :", error);
      this.handleAudioEnd();
    });
  }
}
