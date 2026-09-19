/* -----------------------------------------------------------------------------
 * Dessine l'icône de l'app (Icone.icns) : le cadran, sur papier crème.
 *
 *   swift outils/icone.swift Icone.icns
 *
 * Chaque taille est redessinée en vectoriel plutôt que réduite, pour rester
 * nette. Gabarit macOS : forme de 824 pt dans un carré de 1024.
 * -------------------------------------------------------------------------- */

import AppKit

let sortie = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Icone.icns")

func couleur(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func dessiner(_ cote: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: cote, pixelsHigh: cote, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = CGFloat(cote) / 1024
    let c = NSPoint(x: 512 * k, y: 512 * k)

    // Le papier.
    let forme = NSBezierPath(roundedRect: NSRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k),
                             xRadius: 185 * k, yRadius: 185 * k)
    couleur(0xFAF6EF).setFill()
    forme.fill()

    // L'anneau : le jour à droite (lever en haut), la nuit à gauche.
    func secteur(_ de: CGFloat, _ a: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.appendArc(withCenter: c, radius: 300 * k, startAngle: de, endAngle: a, clockwise: true)
        p.appendArc(withCenter: c, radius: 218 * k, startAngle: a, endAngle: de, clockwise: false)
        p.close()
        return p
    }
    couleur(0xE9CF9C).setFill(); secteur(90, -90).fill()
    couleur(0x24305A).setFill(); secteur(-90, -270).fill()

    // Les vingt-quatre divisions, en filets couleur papier.
    couleur(0xFAF6EF).setStroke()
    for i in 1..<24 where i != 12 {
        let a = (90 - CGFloat(i) * 15) * .pi / 180
        let t = NSBezierPath()
        t.move(to: NSPoint(x: c.x + 218 * k * cos(a), y: c.y + 218 * k * sin(a)))
        t.line(to: NSPoint(x: c.x + 300 * k * cos(a), y: c.y + 300 * k * sin(a)))
        t.lineWidth = max(1, 7 * k)
        t.stroke()
    }

    // Lever et coucher, en or.
    couleur(0xD4A843).setStroke()
    for a in [CGFloat(90), -90] {
        let r = a * .pi / 180
        let t = NSBezierPath()
        t.move(to: NSPoint(x: c.x + 218 * k * cos(r), y: c.y + 218 * k * sin(r)))
        t.line(to: NSPoint(x: c.x + 300 * k * cos(r), y: c.y + 300 * k * sin(r)))
        t.lineWidth = max(1, 10 * k)
        t.stroke()
    }

    // Le soleil, en route vers la sixième heure.
    let a = (90 - 70) * CGFloat.pi / 180
    let s = NSPoint(x: c.x + 352 * k * cos(a), y: c.y + 352 * k * sin(a))
    couleur(0xD4A843).setFill()
    NSBezierPath(ovalIn: NSRect(x: s.x - 34 * k, y: s.y - 34 * k, width: 68 * k, height: 68 * k)).fill()
    if cote >= 64 {
        let halo = NSBezierPath(ovalIn: NSRect(x: s.x - 52 * k, y: s.y - 52 * k, width: 104 * k, height: 104 * k))
        halo.lineWidth = 5 * k
        couleur(0xD4A843, 0.5).setStroke()
        halo.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let jeu = FileManager.default.temporaryDirectory.appendingPathComponent("Icone.iconset")
try? FileManager.default.removeItem(at: jeu)
try! FileManager.default.createDirectory(at: jeu, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! dessiner(base).write(to: jeu.appendingPathComponent("icon_\(base)x\(base).png"))
    try! dessiner(base * 2).write(to: jeu.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", jeu.path, "-o", sortie.path]
try! p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Icône : \(sortie.path)" : "iconutil a échoué")
