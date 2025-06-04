import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "playButtonIcon", "visualWrapper" ] // Exemple de cibles

  connect() {
    console.log("Audio Player Controller connecté!", this.element)
    this.globalAudioPlayer = document.getElementById("global-audio-player");
    this.currentlyPlayingButton = null;
    this.currentVisualWrapper = null;

    if (this.globalAudioPlayer) {
      this._setupGlobalPlayerListeners();
    }
  }

  disconnect() {
    if (this.globalAudioPlayer) {
      // Potentiellement supprimer les écouteurs si nécessaire,
      // mais pour les écouteurs sur globalAudioPlayer, ce n'est pas toujours critique
      // si le contrôleur est déconnecté et reconnecté souvent.
    }
  }

  _setupGlobalPlayerListeners() {
    // Utilise des fonctions fléchées pour conserver le 'this' du contrôleur
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
    this.handleAudioEnd(); // Réinitialise l'état comme à la fin de la lecture
  }

  togglePlay(event) {
    const clickedButton = event.currentTarget;
    const cell = clickedButton.closest(".carousel-cell");
    const visualWrapper = clickedButton.closest(".album-art-visual-wrapper");
    const previewUrl = cell.dataset.previewUrl;
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
      visualWrapper.classList.remove("is-playing");
    } else {
      if (this.currentlyPlayingButton && this.currentlyPlayingButton !== clickedButton) {
        const oldIcon = this.currentlyPlayingButton.querySelector("i");
        oldIcon.classList.remove("bi-pause-fill");
        oldIcon.classList.add("bi-play-fill");
      }
      if (this.currentVisualWrapper && this.currentVisualWrapper !== visualWrapper) {
        this.currentVisualWrapper.classList.remove("is-playing");
      }

      if (this.globalAudioPlayer.src !== previewUrl) {
        this.globalAudioPlayer.src = previewUrl;
      }
      this.globalAudioPlayer.play().then(() => {
        icon.classList.remove("bi-play-fill");
        icon.classList.add("bi-pause-fill");
        visualWrapper.classList.add("is-playing");
        this.currentlyPlayingButton = clickedButton;
        this.currentVisualWrapper = visualWrapper;
      }).catch(error => {
        console.error("Erreur lors de la tentative de lecture :", error);
        icon.classList.remove("bi-pause-fill");
        icon.classList.add("bi-play-fill");
        visualWrapper.classList.remove("is-playing");
      });
    }
  }
}
