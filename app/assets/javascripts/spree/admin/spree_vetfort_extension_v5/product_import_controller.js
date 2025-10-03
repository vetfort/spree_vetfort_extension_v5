import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = [
    "columnPanel",
    "backdrop",
    "commonForm",
    "commonTaxonsSelect",
    "commonPropertiesSelect",
  ]

  static values = {
    path: String,
    productImportRowPath: String,
    productImportField: String,
    addColumnsPath: String,
  }

  connect() {
    this.element.addEventListener("tomSelectInitialized", (event) => {
      if (this.hasCommonFormTarget && this.commonTargets.includes(event.target)) {
        const tom = event.target.tomselect

        tom.on("change", () => {
          this.commonFormTarget.requestSubmit()
        })
      }
    })
  }

  columnPanelTargetConnected() {
    this.columnPanelTarget.style.transform = "translateX(100%)"
    this.backdropTarget.classList.add("d-none")
  }

  toggleColumnPanel() {
    const open = this.columnPanelTarget.style.transform === "translateX(100%)"
    this.columnPanelTarget.style.transform = open ? "translateX(0)" : "translateX(100%)"
    this.backdropTarget.classList.toggle("d-none", !open)
  }

  addColumn(event) {
    event.preventDefault()

    patch(this.addColumnsPathValue, {
      body: {
        field: event.currentTarget.dataset.field
      }
    })
  }

  get commonTargets() {
    return [this.commonPropertiesSelectTarget, this.commonTaxonsSelectTarget]
  }
}
