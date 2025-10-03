import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop", "rowForm", "rowTaxonsSelect", "rowPropertiesSelect"]

  static values = {
    path: String
  }

  connect() {
    this.element.addEventListener("tomSelectInitialized", (event) => {
      if (this.hasRowFormTarget && this.rowTargets.includes(event.target)) {
        const tom = event.target.tomselect

        tom.on("change", () => {
          this.rowFormTarget.requestSubmit()
        })
      }
    })
  }

  toggleDrawer() {
    const open = this.drawerTarget.style.transform === "translateX(100%)"
    this.drawerTarget.style.transform = open ? "translateX(0)" : "translateX(100%)"
    this.backdropTarget.classList.toggle("d-none", !open)
  }

  openDrawer() {
    this.drawerTarget.style.transform = "translateX(0)"
    this.backdropTarget.classList.remove("d-none")
  }

  closeDrawer() {
    this.drawerTarget.style.transform = "translateX(100%)"
    this.backdropTarget.classList.add("d-none")
  }

  autoSubmit() {
    if (this.hasRowFormTarget) {
      this.rowFormTarget.requestSubmit()
    }
  }

  get rowTargets() {
    return [this.rowTaxonsSelectTarget, this.rowPropertiesSelectTarget]
  }
}
