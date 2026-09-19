/* -----------------------------------------------------------------------------
 * L'élément de la barre des menus : icône, numéro de l'heure, menu contextuel.
 *
 *   Clic                → ouvre ou referme le panneau
 *   Clic droit (⌃ clic) → le menu
 *   ⌃⌥H, de partout     → ouvre ou referme le panneau
 * -------------------------------------------------------------------------- */

import AppKit
import Carbon
import ServiceManagement

final class Barre: NSObject, NSApplicationDelegate {

    private static let pageEnLigne = URL(string: "https://abazinet01.github.io/heures-temporaires/")!
    private static let cleNumero = "masquerNumero"

    private var element: NSStatusItem!
    private var panneau: Panneau!
    private var calcul: Calcul?
    private var raccourci: Raccourci?
    private var minuterie: Timer?
    private var resume: Resume?

    private let police: NSFont = {
        let taille = NSFont.systemFontSize
        let base = NSFont.systemFont(ofSize: taille)
        guard let serif = base.fontDescriptor.withDesign(.serif) else { return base }
        return NSFont(descriptor: serif, size: taille) ?? base
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let web = Bundle.main.resourceURL!.appendingPathComponent("web")
        calcul = Calcul(script: web.appendingPathComponent("soleil.js"))
        panneau = Panneau(dossierWeb: web)

        element = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let bouton = element.button {
            bouton.target = self
            bouton.action = #selector(clic(_:))
            bouton.sendAction(on: [.leftMouseUp, .rightMouseUp])
            bouton.imagePosition = .imageLeading
            bouton.font = police
        }

        raccourci = Raccourci(touche: kVK_ANSI_H, modificateurs: controlKey | optionKey) { [weak self] in
            self?.basculer()
        }

        rafraichir()
        // L'heure change environ une fois l'heure ; l'aiguille, elle, avance
        // doucement. Un quart de minute suffit, et la tolérance laisse le
        // système regrouper les réveils.
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in self?.rafraichir() }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        minuterie = t

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(rafraichir),
                                                          name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(rafraichir),
                                               name: .NSSystemClockDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changementDeFuseau),
                                               name: .NSSystemTimeZoneDidChange, object: nil)
    }

    // --- Affichage -----------------------------------------------------------

    @objc private func rafraichir() {
        guard let bouton = element.button else { return }
        guard let r = calcul?.resume() else {
            bouton.title = "?"
            bouton.toolTip = "Le calcul solaire n'a pas pu être chargé."
            return
        }
        resume = r
        bouton.image = Icone.barre(r)
        let numero = UserDefaults.standard.bool(forKey: Self.cleNumero) ? "" : r.romain
        if bouton.title != numero { bouton.title = numero }
        bouton.toolTip = "\(r.nom) · jusqu'à \(Self.hm(r.finHeure))"
        panneau.teinter(nuit: r.estNuit)
    }

    @objc private func changementDeFuseau() {
        calcul?.recharger()
        rafraichir()
    }

    private static func hm(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded() * 60))
    }

    // --- Clics ---------------------------------------------------------------

    @objc private func clic(_ sender: NSStatusBarButton) {
        let evenement = NSApp.currentEvent
        if evenement?.type == .rightMouseUp || evenement?.modifierFlags.contains(.control) == true {
            montrerMenu()
        } else {
            basculer()
        }
    }

    private func basculer() {
        guard let bouton = element.button else { return }
        if panneau.isVisible {
            panneau.fermer()
        } else if Date().timeIntervalSince(panneau.fermeLe) > 0.25 {
            // Le clic qui vient de fermer le panneau ne doit pas le rouvrir.
            panneau.ouvrir(sous: bouton)
        }
    }

    // --- Menu ----------------------------------------------------------------

    private func montrerMenu() {
        panneau.fermer()
        let menu = NSMenu()

        if let r = resume {
            menu.addItem(desactive(r.nom))
            menu.addItem(desactive("Jusqu'à \(Self.hm(r.finHeure)) · \(Int(r.progression * 100)) % écoulée"))
            menu.addItem(.separator())
        }

        let afficher = menu.addItem(withTitle: "Afficher le cadran", action: #selector(afficherDepuisMenu), keyEquivalent: "h")
        afficher.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(withTitle: "Ouvrir la page en ligne", action: #selector(ouvrirEnLigne), keyEquivalent: "")
        menu.addItem(.separator())

        let numero = menu.addItem(withTitle: "Numéro de l'heure dans la barre", action: #selector(basculerNumero), keyEquivalent: "")
        numero.state = UserDefaults.standard.bool(forKey: Self.cleNumero) ? .off : .on

        let session = menu.addItem(withTitle: "Ouvrir à l'ouverture de session", action: #selector(basculerSession), keyEquivalent: "")
        session.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quitter Heures temporaires", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        for item in menu.items where item.action != nil && item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }

        // Le menu n'est attaché que le temps de l'afficher : sinon, il
        // intercepterait aussi le clic gauche.
        element.menu = menu
        element.button?.performClick(nil)
        element.menu = nil
    }

    private func desactive(_ titre: String) -> NSMenuItem {
        let item = NSMenuItem(title: titre, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func afficherDepuisMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.basculer() }
    }

    @objc private func ouvrirEnLigne() { NSWorkspace.shared.open(Self.pageEnLigne) }

    @objc private func basculerNumero() {
        let d = UserDefaults.standard
        d.set(!d.bool(forKey: Self.cleNumero), forKey: Self.cleNumero)
        rafraichir()
    }

    @objc private func basculerSession() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            let alerte = NSAlert(error: error)
            alerte.messageText = "Impossible de modifier l'ouverture à la session"
            alerte.informativeText = error.localizedDescription
                + "\n\nL'app doit se trouver dans le dossier Applications (le vôtre ou celui du Mac)."
            NSApp.activate(ignoringOtherApps: true)
            alerte.runModal()
        }
    }
}
