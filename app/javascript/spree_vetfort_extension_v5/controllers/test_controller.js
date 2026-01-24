import { Controller } from "@hotwired/stimulus"
import { PUUUU } from "spree_vetfort_extension_v5/constants"

export default class extends Controller {
    connect() {
        console.log("Test controller connected", PUUUU);
    }
}