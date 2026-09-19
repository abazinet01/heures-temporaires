/* -----------------------------------------------------------------------------
 * Un raccourci clavier global, par l'API Carbon RegisterEventHotKey.
 *
 * C'est la seule façon d'écouter une touche partout sans demander l'accès
 * « Accessibilité » : le système ne transmet que cette combinaison-là.
 * -------------------------------------------------------------------------- */

import Carbon

final class Raccourci {
    private var reference: EventHotKeyRef?
    private var gestionnaire: EventHandlerRef?
    private let action: () -> Void

    init?(touche: Int, modificateurs: Int, action: @escaping () -> Void) {
        self.action = action

        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let moi = Unmanaged.passUnretained(self).toOpaque()
        let installe = InstallEventHandler(GetApplicationEventTarget(), { _, _, donnees in
            guard let donnees else { return OSStatus(eventNotHandledErr) }
            let raccourci = Unmanaged<Raccourci>.fromOpaque(donnees).takeUnretainedValue()
            DispatchQueue.main.async { raccourci.action() }
            return noErr
        }, 1, &type, moi, &gestionnaire)
        guard installe == noErr else { return nil }

        let id = EventHotKeyID(signature: 0x4854_4D50 /* HTMP */, id: 1)
        guard RegisterEventHotKey(UInt32(touche), UInt32(modificateurs), id,
                                  GetApplicationEventTarget(), 0, &reference) == noErr else { return nil }
    }

    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let gestionnaire { RemoveEventHandler(gestionnaire) }
    }
}
