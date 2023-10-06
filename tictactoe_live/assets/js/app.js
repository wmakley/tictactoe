// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Custom JS:

// Get last player name from local storage:
let playerName = localStorage.getItem("playerName") || ""
console.debug("initial playerName:", playerName)

// Save the player name every time it changes:
window.addEventListener("phx:player_name_changed", (event) => {
  const newName = event.detail.value
  console.debug("phx:player_name_changed to:", newName)
  playerName = newName
  localStorage.setItem("playerName", newName)
})

// Scroll chat to bottom any time the game state changes, as all state changes
// are accompanied by a new chat message:
window.addEventListener("phx:game_state_changed", () => {
  const chat = document.getElementById("chat-messages");
  if (chat) {
    chat.scrollTop = chat.scrollHeight;
  }
})

const Hooks = {
  // Put hooks here if they are ever needed.
}

// Default LiveView setup:

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {
    _csrf_token: csrfToken,
    player_name: playerName,
  },
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
