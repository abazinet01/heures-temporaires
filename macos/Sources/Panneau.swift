/* -----------------------------------------------------------------------------
 * Le panneau qui descend de la barre des menus.
 *
 * Une fenêtre sans bordure, aux coins adoucis, qui glisse de quelques points
 * vers le bas en apparaissant. « Non activante » : elle reçoit le clavier
 * (Échap, Espace) sans voler le premier plan à l'app en cours.
 *
 * Elle se referme d'elle-même dès qu'on clique ailleurs.
 * -------------------------------------------------------------------------- */

import AppKit
import WebKit

final class Panneau: NSPanel, NSWindowDelegate, WKNavigationDelegate {

    private static let largeur: CGFloat = 340
    private static let crème = NSColor(srgbRed: 0xFA / 255, green: 0xF6 / 255, blue: 0xEF / 255, alpha: 1)
    private static let nuit = NSColor(srgbRed: 0x14 / 255, green: 0x1B / 255, blue: 0x2E / 255, alpha: 1)

    private let web: WKWebView
    private let fond = NSView()
    private var hauteur: CGFloat = 470
    private var moniteur: Any?
    private var fermeture = 0          // compteur : une fermeture animée ne doit pas cacher une réouverture
    private(set) var fermeLe = Date.distantPast

    init(dossierWeb: URL) {
        let controleur = WKUserContentController()
        controleur.addUserScript(WKUserScript(source: "window.HT_MODE = 'barre';",
                                              injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let config = WKWebViewConfiguration()
        config.userContentController = controleur
        web = WKWebView(frame: .zero, configuration: config)

        super.init(contentRect: NSRect(x: 0, y: 0, width: Self.largeur, height: hauteur),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)

        controleur.add(Messager(self), name: "barre")

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        delegate = self

        fond.wantsLayer = true
        fond.layer?.cornerRadius = 12
        fond.layer?.cornerCurve = .continuous
        fond.layer?.masksToBounds = true
        fond.layer?.backgroundColor = Self.crème.cgColor
        contentView = fond

        web.frame = fond.bounds
        web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")   // pas d'éclair blanc avant le CSS
        if #available(macOS 13.3, *) { web.isInspectable = true }
        fond.addSubview(web)

        web.loadFileURL(dossierWeb.appendingPathComponent("index.html"), allowingReadAccessTo: dossierWeb)
    }

    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { fermer() }

    /// Teinte de fond sous la page, pour qu'aucun éclair ne trahisse le chargement.
    func teinter(nuit: Bool) {
        fond.layer?.backgroundColor = (nuit ? Self.nuit : Self.crème).cgColor
    }

    // --- Ouvrir et fermer ----------------------------------------------------

    func ouvrir(sous bouton: NSStatusBarButton) {
        guard let fenetre = bouton.window else { return }
        fermeture += 1
        let ancre = fenetre.convertToScreen(bouton.convert(bouton.bounds, to: nil))
        let zone = (fenetre.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let x = min(max(ancre.midX - Self.largeur / 2, zone.minX + 8), zone.maxX - Self.largeur - 8)
        let cible = NSRect(x: x, y: ancre.minY - 6 - hauteur, width: Self.largeur, height: hauteur)

        web.evaluateJavaScript("window.HT && HT.maj()")
        setFrame(cible.offsetBy(dx: 0, dy: 10), display: false)
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().setFrame(cible, display: true)
            animator().alphaValue = 1
        }

        // Un clic dans une autre app referme le panneau. Surveiller la souris
        // ne demande aucune autorisation (seul le clavier en demanderait une).
        moniteur = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.fermer()
        }
    }

    func fermer() {
        guard isVisible else { return }
        if let moniteur { NSEvent.removeMonitor(moniteur) }
        moniteur = nil
        fermeLe = Date()
        fermeture += 1
        let celleCi = fermeture
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.fermeture == celleCi else { return }
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }

    func windowDidResignKey(_ notification: Notification) { fermer() }

    // --- Messages de la page -------------------------------------------------

    fileprivate func recevoir(_ message: [String: Any]) {
        if message["fermer"] != nil { fermer() }
        if let h = message["hauteur"] as? Double { ajuster(hauteur: CGFloat(h)) }
    }

    /// La page annonce sa hauteur ; le panneau s'y ajuste, le haut restant fixe.
    private func ajuster(hauteur nouvelle: CGFloat) {
        let maxi = (screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let h = min(max(nouvelle, 200), maxi - 20)
        guard abs(h - hauteur) > 0.5 else { return }
        hauteur = h
        guard isVisible else { return }
        var cadre = frame
        cadre.origin.y = cadre.maxY - h
        cadre.size.height = h
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            animator().setFrame(cadre, display: true)
        }
    }

    // --- Navigation ----------------------------------------------------------

    /// Un lien ne doit jamais emmener le panneau ailleurs : il part dans le navigateur.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }
}

/// Intermédiaire à référence faible : WKUserContentController retient ses
/// destinataires, et le panneau retient la page — sans lui, un cycle.
private final class Messager: NSObject, WKScriptMessageHandler {
    weak var panneau: Panneau?
    init(_ panneau: Panneau) { self.panneau = panneau }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if let corps = message.body as? [String: Any] { panneau?.recevoir(corps) }
    }
}
