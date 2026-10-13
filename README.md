# Charge — iPhone

Application iOS native en SwiftUI qui interroge Driveco directement depuis
l’iPhone. **Aucun serveur personnel n’est requis** : l’app appelle le proxy
utilisé par le portail mobile Driveco et garde localement les stations choisies.

## Fonctions

- état des bornes et détail des points de charge ;
- packs Blagnac / Saint-Martin ou sélection de stations individuelles ;
- recherche de stations et tri par proximité (position facultative) ;
- relevé manuel et cadence automatique de 1 ou 4 minutes ;
- préférence de stations et cadence mémorisées sur l’iPhone.

## Limites importantes

- L’API utilisée (`m.driveco.app/api/driveco`) n’est **pas une API publique
  documentée**. Driveco peut en modifier ou bloquer l’accès à tout moment.
- L’app ne tourne pas en continu en arrière-plan : iOS suspend les applications
  inactives et ne garantit pas une vérification toutes les 1 ou 4 minutes écran
  éteint. Le relevé périodique fonctionne lorsque l’app reste au premier plan ;
  pour une surveillance permanente avec alertes, il faut un appareil/service
  toujours actif quelque part.
- La carte complète est chargée depuis Driveco à l’ouverture du sélecteur puis
  gardée en mémoire pendant 15 minutes. Le détail exact est relevé pour les
  stations suivies.

## Lancer avec Xcode

1. Ouvre `ChargeIPhone.xcodeproj` sur un Mac avec **Xcode 15 ou ultérieur**.
2. Dans Xcode, choisis le schéma **Charge** et un simulateur iPhone.
3. Appuie sur **▶ Run**. Pour installer sur un iPhone physique, connecte-le au
   Mac, sélectionne-le comme destination et configure une équipe de signature
   dans **Signing & Capabilities**.

Déploiement minimum : iOS 17. L’app ne dépend pas d’un backend ni d’une
configuration d’adresse serveur.

## Travailler depuis un Mac distant

Sur le Mac distant, clone le dépôt une fois :

```sh
git clone https://github.com/blaurans/charge-iphone.git
cd charge-iphone
open ChargeIPhone.xcodeproj
```

Après les mises à jour publiées dans GitHub :

```sh
git pull --ff-only
open ChargeIPhone.xcodeproj
```

Pour piloter Xcode graphiquement sur un Mac distant, il faut une session de
bureau à distance (par exemple Partage d’écran/VNC ou le bureau fourni par
l’hébergeur du Mac). SSH seul permet de lancer `xcodebuild`, mais ne donne pas
l’interface Xcode. Le simulateur tourne sur le Mac ; pour tester sur un iPhone
physique, il faut que l’appareil soit associé à ce Mac (USB ou débogage sans fil
déjà configuré).
