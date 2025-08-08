import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["backdrop", "columnPanel"];

  toggleColumnPanel() {
    const isVisible = this.columnPanelTarget.style.transform === "translateX(0%)";
    this.columnPanelTarget.style.transform = isVisible ? "translateX(100%)" : "translateX(0%)";
    this.backdropTarget.style.display = isVisible ? "none" : "block";
  }

  addColumn(event) {
    // Logic to add a column
  }

  updateCommon(event) {
    // Logic to update common values
  }

  remap(event) {
    // Logic to remap fields
  }

  removeColumn(event) {
    // Logic to remove a column
  }

  updateRow(event) {
    // Logic to update a row
  }
}
