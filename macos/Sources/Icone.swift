/* -----------------------------------------------------------------------------
 * L'icône de la barre : le cadran en miniature.
 *
 * Un anneau épais pour le jour, fin pour la nuit, et une aiguille qui pointe
 * l'instant présent. Le lever est en haut, comme sur le cadran de la page.
 * Image « modèle » : macOS la teinte lui-même selon la barre claire ou sombre.
 * -------------------------------------------------------------------------- */

import AppKit

enum Icone {

    static func barre(_ r: Resume) -> NSImage {
        let image = NSImage(size: NSSize(width: 17, height: 17), flipped: false) { cadre in
            let c = NSPoint(x: cadre.midX, y: cadre.midY)
            let rayon: CGFloat = 6.4
            let haut: CGFloat = 90
            let coucher = haut - 360 * CGFloat(r.fractionCoucher)
            let ici = haut - 360 * CGFloat(r.fractionMaintenant)

            // La nuit : un filet, un peu estompé.
            let nuit = NSBezierPath()
            nuit.appendArc(withCenter: c, radius: rayon, startAngle: coucher, endAngle: haut - 360, clockwise: true)
            nuit.lineWidth = 1
            NSColor.black.withAlphaComponent(0.55).setStroke()
            nuit.stroke()

            // Le jour : un trait plein.
            let jour = NSBezierPath()
            jour.appendArc(withCenter: c, radius: rayon, startAngle: haut, endAngle: coucher, clockwise: true)
            jour.lineWidth = 2.4
            NSColor.black.setStroke()
            jour.stroke()

            // L'aiguille.
            let a = ici * .pi / 180
            let aiguille = NSBezierPath()
            aiguille.move(to: c)
            aiguille.line(to: NSPoint(x: c.x + 4.1 * cos(a), y: c.y + 4.1 * sin(a)))
            aiguille.lineWidth = 1.5
            aiguille.lineCapStyle = .round
            aiguille.stroke()
            NSBezierPath(ovalIn: NSRect(x: c.x - 1.3, y: c.y - 1.3, width: 2.6, height: 2.6)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = r.nom
        return image
    }
}
