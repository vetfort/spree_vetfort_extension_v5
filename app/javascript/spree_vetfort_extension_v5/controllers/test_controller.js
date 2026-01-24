import { Controller } from "@hotwired/stimulus"
import { PUUUU } from "../constants.js"

export default class extends Controller {
    connect() {
        console.log("Test controller connected", PUUUU);
    }
}