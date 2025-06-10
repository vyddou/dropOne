// app/javascript/controllers/tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "pane" ]

  connect() {
    this.tabs = this.element.querySelectorAll(".nav-tab-modern");
  }

  switchTab(event) {
    event.preventDefault();
    const tabName = event.currentTarget.dataset.tabName;

    // Met à jour les classes des onglets
    this.tabs.forEach(tab => {
      tab.classList.toggle("active", tab.dataset.tabName === tabName);
    });

    // Met à jour les classes des panneaux de contenu
    this.paneTargets.forEach(pane => {
      const paneIsActive = pane.id === `${tabName}-content`;
      pane.classList.toggle("active", paneIsActive);
      // Utilise d-none de Bootstrap pour cacher les panneaux inactifs
      pane.classList.toggle("d-none", !paneIsActive);
    });
  }
}
