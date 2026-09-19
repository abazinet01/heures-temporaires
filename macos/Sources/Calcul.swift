/* -----------------------------------------------------------------------------
 * Le calcul, emprunté tel quel à la page : soleil.js tourne dans JavaScriptCore.
 * L'icône de la barre et le cadran du panneau ne peuvent donc pas diverger.
 * -------------------------------------------------------------------------- */

import Foundation
import JavaScriptCore

/// Ce que renvoie Soleil.resume() dans soleil.js.
struct Resume {
    let periode: String            // « jour » ou « nuit »
    let romain: String             // « VI »
    let nom: String                // « Sixième heure du jour »
    let progression: Double        // 0 à 1 dans l'heure en cours
    let finHeure: Date
    let fractionCoucher: Double    // place du coucher dans le cycle, 0 à 1
    let fractionMaintenant: Double // place de l'instant dans le cycle, 0 à 1

    var estNuit: Bool { periode == "nuit" }
}

final class Calcul {
    private let script: String
    private var contexte: JSContext!

    init?(script url: URL) {
        guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        script = source
        recharger()
    }

    /// Un nouveau contexte relit le fuseau horaire du système.
    func recharger() {
        contexte = JSContext()
        contexte.exceptionHandler = { _, exception in
            NSLog("soleil.js : %@", exception?.toString() ?? "erreur inconnue")
        }
        contexte.evaluateScript(script)
    }

    func resume(_ date: Date = Date()) -> Resume? {
        guard let soleil = contexte.objectForKeyedSubscript("Soleil"), soleil.isObject,
              let lieu = soleil.objectForKeyedSubscript("QUEBEC") else { return nil }
        let ms = date.timeIntervalSince1970 * 1000
        guard let r = soleil.invokeMethod("resume", withArguments: [
                  ms, lieu.objectForKeyedSubscript("lat").toDouble(), lieu.objectForKeyedSubscript("lng").toDouble()
              ]), r.isObject else { return nil }

        func nombre(_ cle: String) -> Double { r.objectForKeyedSubscript(cle).toDouble() }
        func texte(_ cle: String) -> String { r.objectForKeyedSubscript(cle).toString() }

        return Resume(
            periode: texte("periode"),
            romain: texte("romain"),
            nom: texte("nom"),
            progression: nombre("progression"),
            finHeure: Date(timeIntervalSince1970: nombre("finHeure") / 1000),
            fractionCoucher: nombre("fractionCoucher"),
            fractionMaintenant: nombre("fractionMaintenant")
        )
    }
}
