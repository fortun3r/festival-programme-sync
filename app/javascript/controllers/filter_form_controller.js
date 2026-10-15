import { Controller } from "@hotwired/stimulus"

// Submits the screenings filter form as filters change: straight away for the
// date and venue, after a pause in typing for the title search. The form
// targets the results frame, so only the results reload.
export default class extends Controller {
  submit() {
    clearTimeout(this.timeout)
    // requestSubmit, not submit(): it fires the submit event Turbo listens for.
    this.element.requestSubmit()
  }

  debouncedSubmit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 300)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
