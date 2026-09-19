/* -----------------------------------------------------------------------------
 * Heures temporaires — app de la barre des menus
 *
 * La page reste la page : index.html et soleil.js sont copiés tels quels dans
 * le paquet. Le natif ne fait que trois choses que le web ne sait pas faire :
 *
 *   1. Montrer l'heure temporaire dans la barre des menus, en tout temps
 *      (Barre.swift, qui fait tourner soleil.js dans JavaScriptCore).
 *   2. Faire descendre la page sous l'icône, d'un clic ou d'un raccourci
 *      (Panneau.swift, Raccourci.swift).
 *   3. Se lancer à l'ouverture de session, si on le demande.
 *
 * Aucune autorisation système : ni accessibilité, ni localisation, ni réseau.
 * -------------------------------------------------------------------------- */

import AppKit

let app = NSApplication.shared
let barre = Barre()
app.delegate = barre
app.setActivationPolicy(.accessory)   // pas d'icône dans le Dock
app.run()
