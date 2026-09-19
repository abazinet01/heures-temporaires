# Heures temporaires

Le jour divisé en douze heures du lever au coucher, la nuit en douze heures du
coucher au lever — comme dans l'Antiquité. L'été, les heures du jour s'étirent
jusqu'à 80 minutes ; l'hiver, elles fondent à 43.

En ligne : <https://abazinet01.github.io/heures-temporaires/>

## Les versions

| | Où la trouver |
|---|---|
| **v1, l'originale** (février 2026) | étiquette git `v1-originale` · dossier `v1/` (donc `…/heures-temporaires/v1/` une fois publiée) |
| **v2** | branche `v2` : `index.html` + `soleil.js`, et l'app de la barre des menus dans `macos/` |

Revenir à l'originale, à tout moment :

```bash
git checkout v1-originale -- index.html
```

## Ce qui a changé en v2

- **Calcul plus juste.** La position du Soleil est évaluée à l'heure même du
  lever ou du coucher, plus à minuit UTC. Le coucher du 19 septembre 2026 à
  Québec passe de 18:50 à 18:48, ce que donne aussi l'observatoire naval
  américain (USNO). Le passage à l'heure d'été et minuit sont gérés en
  instants réels.
- **La page vit au rythme du Soleil.** Au coucher, toute la page passe au bleu
  nuit. En v1, seul le texte changeait : la nuit, il devenait beige sur crème.
- **Un cadran à plat.** Des aplats plutôt que des dégradés et des halos, les
  chiffres romains au milieu de chaque heure, et le soleil (ou la lune) qui
  fait le tour à l'extérieur de l'anneau.
- **Plus d'information utile** : « Sixième heure du jour », la fin de l'heure
  en cours (à la sixième heure, c'est le midi vrai), la durée du jour et son
  écart avec la veille, le temps qui reste.
- **Tables allégées** : une ligne par heure, les heures passées estompées.

## Regarder la page en local

N'importe quel serveur statique, par exemple :

```bash
python3 -m http.server 8140
```

Deux paramètres d'adresse, pour les essais :

- `?t=2026-12-21T22:00` fait comme s'il était cette heure-là (le temps avance
  ensuite normalement). Pratique pour voir la nuit en plein jour.
- `?barre` affiche la page comme dans le panneau de la barre des menus.

## L'app de la barre des menus

Un cadran miniature et le numéro de l'heure (« VI ») dans la barre des menus.
Un clic fait descendre le cadran complet.

| | |
|---|---|
| Clic | ouvre ou referme le panneau |
| `⌃⌥H`, de n'importe où | ouvre ou referme le panneau |
| `Échap` ou un clic ailleurs | referme |
| `Espace` dans le panneau | déplie les vingt-quatre heures |
| Clic droit | menu : page en ligne, numéro dans la barre, ouverture à la session, quitter |

Construire et installer (dans `~/Applications`, sans mot de passe) :

```bash
./macos/construire.sh --installer
```

Pas besoin d'Xcode : les outils de ligne de commande suffisent. L'app ne
demande aucune autorisation (ni accessibilité, ni localisation, ni réseau).

Elle embarque une **copie** de `index.html` et `soleil.js` au moment de la
construction. Après une modification de la page, reconstruire.

```
macos/
├── construire.sh        construit l'app dans build/
├── Info.plist
├── Icone.icns           généré par outils/icone.swift
└── Sources/
    ├── main.swift       point d'entrée
    ├── Barre.swift      l'icône, le numéro, le menu
    ├── Panneau.swift    la fenêtre qui descend, et la page dedans
    ├── Calcul.swift     soleil.js dans JavaScriptCore
    ├── Icone.swift      le cadran miniature
    └── Raccourci.swift  ⌃⌥H
```

Le calcul n'existe qu'une fois, dans `soleil.js` : la page l'utilise par une
balise `<script>`, l'app par JavaScriptCore. L'icône et le cadran ne peuvent
pas se contredire.

## Crédits

Calcul solaire : algorithme de la NOAA.
