/* -----------------------------------------------------------------------------
 * soleil.js — le calcul, et rien d'autre.
 *
 * Aucun DOM, aucune horloge : on donne un instant (en millisecondes) et un lieu,
 * on reçoit l'état des heures temporaires. Le même fichier sert deux fois :
 *
 *   - dans la page (index.html), par une balise <script> ;
 *   - dans l'app de la barre des menus, par JavaScriptCore.
 *
 * Une seule source de vérité : l'icône de la barre et le cadran ne peuvent pas
 * diverger.
 *
 * Algorithme solaire de la NOAA, comme dans la version originale, avec deux
 * corrections :
 *   - la position du Soleil est évaluée à l'instant même du lever ou du
 *     coucher (trois itérations), plutôt qu'à minuit UTC ;
 *   - tout est calculé en instants réels (UTC), ce qui règle d'office le
 *     passage à l'heure d'été et le franchissement de minuit.
 * -------------------------------------------------------------------------- */

var Soleil = (function () {
  'use strict';

  var RAD = Math.PI / 180;
  var MINUTE = 60000;
  var JOUR = 86400000;

  var QUEBEC = { nom: 'Québec', lat: 46.8139, lng: -71.2080 };

  var ORDINAUX = ['Première', 'Deuxième', 'Troisième', 'Quatrième', 'Cinquième',
    'Sixième', 'Septième', 'Huitième', 'Neuvième', 'Dixième', 'Onzième', 'Douzième'];
  var ROMAINS = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII'];

  // --- Position du Soleil (NOAA) --------------------------------------------

  /** Siècles juliens depuis J2000, à partir d'un instant Unix en ms. */
  function siecle(ms) {
    return (ms / JOUR + 2440587.5 - 2451545) / 36525;
  }

  /** Équation du temps (minutes) et déclinaison (degrés) au siècle T. */
  function position(T) {
    var L0 = ((280.46646 + T * (36000.76983 + 0.0003032 * T)) % 360 + 360) % 360;
    var M = 357.52911 + T * (35999.05029 - 0.0001537 * T);
    var e = 0.016708634 - T * (0.000042037 + 0.0000001267 * T);
    var Mr = M * RAD;
    var C = Math.sin(Mr) * (1.914602 - T * (0.004817 + 0.000014 * T))
          + Math.sin(2 * Mr) * (0.019993 - 0.000101 * T)
          + Math.sin(3 * Mr) * 0.000289;
    var omega = (125.04 - 1934.136 * T) * RAD;
    var lambda = (L0 + C - 0.00569 - 0.00478 * Math.sin(omega)) * RAD;
    var eps0 = 23 + (26 + (21.448 - T * (46.815 + T * (0.00059 - T * 0.001813))) / 60) / 60;
    var eps = (eps0 + 0.00256 * Math.cos(omega)) * RAD;
    var y = Math.tan(eps / 2); y *= y;
    var L0r = L0 * RAD;
    var eqTemps = 4 / RAD * (y * Math.sin(2 * L0r)
      - 2 * e * Math.sin(Mr)
      + 4 * e * y * Math.sin(Mr) * Math.cos(2 * L0r)
      - 0.5 * y * y * Math.sin(4 * L0r)
      - 1.25 * e * e * Math.sin(2 * Mr));
    return { eqTemps: eqTemps, decl: Math.asin(Math.sin(eps) * Math.sin(lambda)) / RAD };
  }

  /**
   * Instant (ms UTC) d'un événement solaire pour une date civile locale.
   * sens : -1 = lever, +1 = coucher, 0 = midi vrai.
   * Renvoie null si le Soleil ne se lève ou ne se couche pas ce jour-là.
   */
  function evenement(an, mois, jour, lieu, sens) {
    var minuitUTC = Date.UTC(an, mois - 1, jour);
    var minutes = 720 - 4 * lieu.lng;            // première estimation : midi moyen
    for (var i = 0; i < 3; i++) {
      var p = position(siecle(minuitUTC + minutes * MINUTE));
      var angle = 0;
      if (sens) {
        var lat = lieu.lat * RAD, d = p.decl * RAD;
        var c = Math.cos(90.833 * RAD) / (Math.cos(lat) * Math.cos(d)) - Math.tan(lat) * Math.tan(d);
        if (c > 1 || c < -1) return null;
        angle = Math.acos(c) / RAD;
      }
      minutes = 720 - 4 * lieu.lng - p.eqTemps + sens * 4 * angle;
    }
    return minuitUTC + minutes * MINUTE;
  }

  /** Lever, coucher et midi vrai du jour civil local qui contient `ms`, décalé de `n` jours. */
  function journee(ms, n, lieu) {
    var ici = new Date(ms);
    var d = new Date(ici.getFullYear(), ici.getMonth(), ici.getDate() + n);
    var a = d.getFullYear(), m = d.getMonth() + 1, j = d.getDate();
    var j0 = {
      lever: evenement(a, m, j, lieu, -1),
      coucher: evenement(a, m, j, lieu, 1),
      midi: evenement(a, m, j, lieu, 0)
    };
    if (j0.lever === null || j0.coucher === null) {
      throw new Error('Le Soleil ne se lève ou ne se couche pas à cette latitude aujourd’hui.');
    }
    return j0;
  }

  /** Les douze heures d'une période, en instants. */
  function douze(debut, fin) {
    var d = (fin - debut) / 12, h = [];
    for (var i = 0; i < 12; i++) h.push({ debut: debut + i * d, fin: debut + (i + 1) * d });
    return h;
  }

  // --- L'état complet -------------------------------------------------------

  /**
   * Tout ce qu'il faut pour dessiner le cadran à l'instant `ms`.
   *
   * Le cadran couvre un « cycle » : d'un lever au lever suivant. Avant l'aube,
   * on est donc à la fin du cycle commencé la veille.
   */
  function etat(ms, lieu) {
    lieu = lieu || QUEBEC;
    var hier = journee(ms, -1, lieu);
    var auj = journee(ms, 0, lieu);
    var dem = journee(ms, 1, lieu);

    var periode, debut, fin, cycle, nuit;
    if (ms < auj.lever) {                         // nuit, avant l'aube
      periode = 'nuit'; debut = hier.coucher; fin = auj.lever;
      cycle = { debut: hier.lever, coucher: hier.coucher, fin: auj.lever };
      nuit = { debut: hier.coucher, fin: auj.lever };
    } else if (ms < auj.coucher) {                // jour
      periode = 'jour'; debut = auj.lever; fin = auj.coucher;
      cycle = { debut: auj.lever, coucher: auj.coucher, fin: dem.lever };
      nuit = { debut: auj.coucher, fin: dem.lever };
    } else {                                      // nuit, après le coucher
      periode = 'nuit'; debut = auj.coucher; fin = dem.lever;
      cycle = { debut: auj.lever, coucher: auj.coucher, fin: dem.lever };
      nuit = { debut: auj.coucher, fin: dem.lever };
    }

    var duree = (fin - debut) / 12;
    var index = Math.min(11, Math.floor((ms - debut) / duree));
    var debutHeure = debut + index * duree;

    return {
      instant: ms,
      lieu: lieu,
      periode: periode,
      index: index,                                // 0 à 11
      romain: ROMAINS[index],
      nom: ORDINAUX[index] + ' heure ' + (periode === 'jour' ? 'du jour' : 'de la nuit'),
      debutHeure: debutHeure,
      finHeure: debutHeure + duree,
      dureeHeure: duree,                           // ms
      progression: (ms - debutHeure) / duree,      // 0 à 1
      debutPeriode: debut,
      finPeriode: fin,
      cycle: cycle,
      aujourdhui: auj,
      dureeJour: auj.coucher - auj.lever,
      dureeJourHier: hier.coucher - hier.lever,
      heuresJour: douze(auj.lever, auj.coucher),
      heuresNuit: douze(nuit.debut, nuit.fin)
    };
  }

  /** Position d'un instant dans le cycle, de 0 (lever) à 1 (lever suivant). */
  function fraction(e, ms) {
    return (ms - e.cycle.debut) / (e.cycle.fin - e.cycle.debut);
  }

  /** Version plate, pour l'app de la barre des menus (JavaScriptCore). */
  function resume(ms, lat, lng) {
    var e = etat(ms, { nom: '', lat: lat, lng: lng });
    return {
      periode: e.periode,
      index: e.index,
      romain: e.romain,
      nom: e.nom,
      progression: e.progression,
      finHeure: e.finHeure,
      dureeHeure: e.dureeHeure,
      fractionCoucher: fraction(e, e.cycle.coucher),
      fractionMaintenant: fraction(e, ms)
    };
  }

  return {
    QUEBEC: QUEBEC,
    ORDINAUX: ORDINAUX,
    ROMAINS: ROMAINS,
    etat: etat,
    fraction: fraction,
    resume: resume
  };
})();
