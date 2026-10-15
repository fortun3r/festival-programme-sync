import { Controller } from "@hotwired/stimulus"

// Submits the screenings filter form as filters change: straight away for the
// date and venue, after a pause in typing for the title search. The form
// targets the results frame, so only the results reload.
export default class extends Controller {
  submit() {
    // requestSubmit, not submit(): it fires the submit event Turbo listens for.
    this.element.requestSubmit()
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 300)
  }

  // Runs on every submit of the form (ours, Enter, the Filter button), so a
  // debounced submit still pending doesn't send the same request again.
  cancelPending() {
    clearTimeout(this.timeout)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
