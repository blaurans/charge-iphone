# Handoff — Charge iPhone

Mis à jour le 14 octobre 2026.

## Décisions prises

- Application **iOS native SwiftUI**, sans serveur personnel : l’iPhone appelle Driveco directement.
- Conserver les packs Blagnac / Saint-Martin et le sélecteur de stations du projet source.
- Cadence proposée : 1 ou 4 minutes. Les relevés automatiques ne sont possibles que tant qu’iOS laisse l’app active au premier plan.
- L’utilisateur a demandé des publications GitHub régulières. Les jalons déjà réalisés ont été poussés sur `main`.
- Une icône originale sombre et verte, représentant une borne et un éclair, est utilisée par l’app.

## Dépôt et état Git

- Dépôt : `https://github.com/blaurans/charge-iphone`
- Copie de travail actuelle : `/tmp/opencode/charge-iphone`
- Branche : `main`.
- Dernier commit applicatif : `8377870 feat: add custom iOS app icon`
- Commit applicatif précédent : `08bc543 feat: create serverless native iOS app`
- Aucun secret ni identifiant d’accès n’est consigné dans ce fichier.

## Fichiers à rouvrir

- `ChargeIPhone.xcodeproj/project.pbxproj` — configuration de la cible iOS et de l’asset catalog.
- `ChargeIPhone/ChargeModel.swift` — appels directs au proxy Driveco, packs, cadence, cache de carte et préférences locales.
- `ChargeIPhone/Models.swift` — modèles de réponse Driveco et modèles UI.
- `ChargeIPhone/ContentView.swift` — tableau de bord SwiftUI et sélecteur de stations.
- `ChargeIPhone/LocationManager.swift` — localisation facultative pour trier les stations.
- `ChargeIPhone/Info.plist` — permissions iOS.
- `ChargeIPhone/Assets.xcassets/AppIcon.appiconset/` — icône iOS 1024 × 1024 et `Contents.json`.
- `Design/ChargeIcon.svg` — source vectorielle de l’icône.
- `README.md` — instructions Xcode/Mac distant et limites connues.

## Fait

- Application native configurée pour iOS 17+, schéma Xcode `Charge`, sans dépendance externe.
- Relevé manuel et actualisation périodique au premier plan ; affichage des disponibilités et détails des points de charge.
- Packs prédéfinis, choix individuel, recherche, tri par distance facultatif et conservation des préférences localement.
- Icône ajoutée à `Assets.xcassets` et déclarée comme `AppIcon` en Debug et Release.
- Guide initial d’utilisation d’Xcode sur un Mac distant écrit dans `README.md`.
- Validations locales effectuées : `Info.plist` et schéma XML valides ; `Contents.json` valide ; PNG 1024 × 1024 RGB ; références d’identifiants du projet Xcode cohérentes ; `git diff --check` sans erreur.
- Push GitHub confirmé pour les commits applicatifs `08bc543` et `8377870` ; ce fichier de reprise est ajouté séparément.

## Limites et problèmes ouverts

- **Aucune compilation Xcode n’a été faite** : l’environnement actuel est Linux et ne possède pas `xcodebuild`/le SDK iOS.
- L’accès direct à `https://m.driveco.app/api/driveco` et le décodage réel des réponses n’ont pas été validés depuis l’app sur iPhone. Cette API n’est pas publique/documentée et peut changer ou refuser l’app.
- iOS suspend l’app en arrière-plan : la cadence 1/4 min n’est pas garantie écran éteint ou app fermée. La surveillance permanente et les alertes du watcher/site ne sont pas reproduites dans cette version sans serveur.
- L’utilisateur a indiqué que l’iPhone était connecté, mais on ne peut pas retrouver s’il est branché/associé au Mac qui exécute Xcode, ni son état de confiance/débogage.
- On ne connaît pas le chemin local du clone sur le Mac distant, la version d’Xcode/macOS, ni les éventuelles erreurs de signature ou de compilation.

## Prochaine action

Sur le Mac distant, dans le clone du dépôt :

```sh
git pull --ff-only
```

Xcode étant ouvert, accepter **Reload** s’il le propose. Choisir le schéma `Charge`, sélectionner l’iPhone comme destination, activer **Automatically manage signing** et sélectionner une équipe dans **Signing & Capabilities**, puis lancer **▶ Run**. Si Xcode échoue, récupérer la première erreur de compilation/signature pour corriger le projet avant le prochain push.

Si la compilation passe, tester ensuite sur l’iPhone : accès réseau à Driveco, chargement du tableau de bord, packs, sélection/recherche de stations et actualisation. Vérifier tout particulièrement les erreurs de décodage JSON ou un refus du proxy Driveco.
