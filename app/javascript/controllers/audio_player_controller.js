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

  togglePlay(event) {
    const clickedButton = event.currentTarget;

    // Déclare les wrappers
    const cell = clickedButton.closest(".carousel-cell");
    const cardTop = clickedButton.closest(".card-img-top");
    const visualWrapper = clickedButton.closest(".album-art-visual-wrapper");

    // Recherche previewUrl dans l'ordre
    let previewUrl = cell?.dataset.previewUrl
                 || cardTop?.dataset.previewUrl
                 || visualWrapper?.dataset.previewUrl
                 || visualWrapper?.dataset.audioPlayerPreviewUrlValue;

    const icon = clickedButton.querySelector("i");

    if (!previewUrl) {
      console.warn("Aucune URL d'extrait disponible pour ce morceau.");
      return;
    }

    if (!this.globalAudioPlayer) {
      console.error("Lecteur audio global non trouvé.");
      return;
    }

    if (this.globalAudioPlayer.src === previewUrl && !this.globalAudioPlayer.paused) {
      this.globalAudioPlayer.pause();
      icon.classList.remove("bi-pause-fill");
      icon.classList.add("bi-play-fill");

      if (cell) cell.classList.remove("is-playing");
      if (cardTop) cardTop.classList.remove("is-playing");
      if (visualWrapper) visualWrapper.classList.remove("is-playing");

    } else {
      if (this.currentlyPlayingButton && this.currentlyPlayingButton !== clickedButton) {
        const oldIcon = this.currentlyPlayingButton.querySelector("i");
        oldIcon.classList.remove("bi-pause-fill");
        oldIcon.classList.add("bi-play-fill");
      }
      if (this.currentVisualWrapper && this.currentVisualWrapper !== (cell || cardTop || visualWrapper)) {
        this.currentVisualWrapper.classList.remove("is-playing");
      }

      if (this.globalAudioPlayer.src !== previewUrl) {
        this.globalAudioPlayer.src = previewUrl;
      }
      this.globalAudioPlayer.play().then(() => {
        icon.classList.remove("bi-play-fill");
        icon.classList.add("bi-pause-fill");

        const playingWrapper = cell || cardTop || visualWrapper;
        if (playingWrapper) playingWrapper.classList.add("is-playing");

        this.currentlyPlayingButton = clickedButton;
        this.currentVisualWrapper = playingWrapper;
      }).catch(error => {
        console.error("Erreur lors de la tentative de lecture :", error);
        icon.classList.remove("bi-pause-fill");
        icon.classList.add("bi-play-fill");

        const playingWrapper = cell || cardTop || visualWrapper;
        if (playingWrapper) playingWrapper.classList.remove("is-playing");
      });
    }
  }
}
