// app/javascript/controllers/flash_auto_dismiss_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    setTimeout(() => {
      this.element.classList.remove("show")
      this.element.classList.add("fade")
    }, 2300) //4 secondes

    setTimeout(() => {
      this.element.remove()
    }, 3000) // 1s plus tard
  }
}
