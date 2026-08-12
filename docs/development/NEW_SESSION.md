# FlutterCheck — Passation de session

Ce document résume l'état du projet à la fin de cette session, pour permettre à une
nouvelle session de reprendre le développement sans perdre le contexte ni
recontredire des décisions déjà validées.

**À lire en complément** : le document maître du projet (contexte produit, architecture
cible, règles de collaboration) — celui qui a servi de base à toute cette session.
Ce présent document ne le remplace pas, il documente ce qui a été _décidé et codé_
depuis.

**Règles de collaboration à rappeler explicitement à la nouvelle session** (issues du
doc maître, à faire respecter dès le premier message) :

- Ne jamais prendre une décision structurante (changement de stack, de stratégie de
  résolution, ajout de dépendance majeure, etc.) sans l'expliquer et attendre validation.
- Pas de code prématuré / pas de tests pour l'instant (décision explicite de
  l'utilisateur, toujours en vigueur à la fin de cette session).
- Signaler les décisions mineures plutôt que les prendre en silence.
- Un sujet à la fois, avancer étape par étape.

---

## 1. Architecture générale (confirmée, ne pas rediscuter)

Monorepo avec dossiers racine **volontairement préfixés** `_apps/` et `_packages/`
(décision assumée par l'utilisateur, ne pas "corriger").

```
fluttercheck/
├── _apps/
│   ├── api/       (Dart, Shelf — non commencé)
│   ├── cli/       (Dart — EN COURS, voir section 3)
│   └── web/       (Next.js/TS — non commencé)
├── _packages/
│   └── core/      (Dart — TERMINÉ structurellement, voir section 2)
├── docs/
├── pnpm-workspace.yaml   (racine, membre: apps/web)
├── package.json          (racine)
└── scripts/
```

Ordre de développement suivi (Phase 0 → 7 du doc maître) : on est actuellement en
**Phase 2 (CLI)**, la Phase 1 (Core) étant structurellement complète.

---

## 2. `packages/core` — état : structurellement complet

Toutes les couches prévues sont codées, exportées depuis `fluttercheck_core.dart`,
et compilent (`dart analyze` → _no issues found_ à la fin de la session).

### Décisions structurantes validées (ne pas redemander)

| Décision                                                                      | Choix retenu                                                                                                                                                  | Raison                                                              |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| SemVer / contraintes de version                                               | **`pub_semver`** (package officiel Dart)                                                                                                                      | Même sémantique que `pub` lui-même ; ne pas réinventer              |
| Parsing YAML                                                                  | **`yaml`** (officiel)                                                                                                                                         | Outillage nécessaire, pas structurant                               |
| Édition non-destructive de pubspec.yaml                                       | **`yaml_edit`** (officiel)                                                                                                                                    | Préserve commentaires/formatage                                     |
| Accès aux métadonnées pub.dev (versions publiées + pubspec de chaque version) | **Interface abstraite dans le Core** (`PackageMetadataSource`), implémentation HTTP hors du Core                                                              | Garde le Core pur/testable, pas d'I/O dedans                        |
| Stratégie de résolution de versions                                           | **Invoquer le vrai `pub`** (sous-processus `dart`/`flutter pub get/upgrade --dry-run`) via une interface abstraite (`PubRunner`), implémentation hors du Core | Ne pas réimplémenter PubGrub ; fiabilité (section 16 du doc maître) |

### Recherche effectuée (résultats, à ne pas refaire)

- **PubGrub** : algorithme de résolution de Pub (CDCL/SAT), conçu par Natalie
  Weizenbaum en 2018. Principe de base confirmé : pour chaque paquet, Pub
  intersecte toutes les contraintes venant de ce qui en dépend — exactement ce
  qu'implémente `Constraints.intersectAll`.
- **pub.dev API** : `GET https://pub.dev/api/packages/<package>` (spec "Hosted Pub
  Repository V2") retourne toutes les versions publiées d'un paquet, **chacune avec
  son propre pubspec complet en JSON** — c'est la source qui permet de construire le
  graphe transitif réel.
- **pub cache local** (`$PUB_CACHE`, `~/.pub-cache`) : alternative/complément
  offline, mais ne contient que les versions déjà téléchargées sur la machine —
  incomplet pour explorer de nouvelles versions. Non utilisé pour l'instant.
- **Outils CLI pub existants** : `dart pub outdated --json` (JSON documenté,
  fiable) ; `dart pub deps --json` (JSON du graphe résolu, mais **ne fonctionne pas**
  si `pub get` échoue — inutilisable pour diagnostiquer un conflit) ; `dart/flutter
pub get/upgrade --dry-run` (aucun format JSON documenté pour les lignes de
  changement — voir limite connue ci-dessous).

### Inventaire des fichiers créés dans `packages/core/lib/src/`

```
models/
  version.dart              — wrap pub_semver.Version
  constraint.dart            — wrap pub_semver.VersionConstraint (+ factory interne _fromRaw)
  package.dart                — inclut PackageSource.project (nœud synthétique du graphe)
  dependency.dart
  environment.dart            — + copyWith() (ajouté pour ProjectLoader du CLI)
  project.dart
  dependency_graph.dart
  issue.dart
  recommendation.dart
  fix.dart
  analysis_result.dart        — PAS ENCORE ASSEMBLÉ par un flux réel (voir section 4)
  package_metadata.dart       — PackageMetadata / PackageVersionMetadata
  pub_solve_result.dart       — PubSolveResult, PubCommand, OutdatedPackageInfo
  verification_result.dart

versions/
  version_utils.dart

constraints/
  constraint_utils.dart       — intersectAll, unionAll, areCompatible, allowedVersions

parsers/
  pubspec_parser.dart         — parse() délègue à parseMap() (réutilisé pour JSON pub.dev)
  pubspec_lock_parser.dart

dependencies/
  dependency_merger.dart      — fusionne pubspec.yaml + pubspec.lock (lockfile prioritaire si présent)
  project_builder.dart

graph/
  graph_builder.dart          — arêtes projet→directes UNIQUEMENT (voir limite connue)

analyzer/
  compatibility_analyzer.dart — sdkMismatch
  dependency_analyzer.dart    — outOfSyncLockfile, missingPackage
  project_analyzer.dart       — orchestre les deux ci-dessus. TODO explicite : versionConflict
                                 et incompatibleSdkConstraint transitifs pas encore détectés ici
                                 (c'est le resolver qui couvre versionConflict, via pub réel)

metadata/  (dossier ajouté en cours de route, pas dans la liste initiale du doc maître)
  package_metadata_source.dart — interface PackageMetadataSource

resolver/
  pub_runner.dart              — interface PubRunner (getDryRun, upgradeDryRun,
                                  upgradeMajorVersionsDryRun, outdated)
  dependency_resolver.dart     — DependencyResolver.resolve() : appelle PubRunner,
                                  transforme le résultat en Issue/Recommendation

recommendations/
  issue_recommender.dart       — couvre outOfSyncLockfile, missingPackage, sdkMismatch
                                  (PAS versionConflict, volontairement — géré par le resolver)

fixes/
  fix_generator.dart           — Recommendation → Fix (seulement si package+version connus)
  pubspec_editor.dart          — applique des Fix à un pubspec.yaml via yaml_edit

verification/
  fix_verifier.dart            — re-vérifie via PubRunner.getDryRun après application des fixes
```

### Limites connues et assumées (ne pas re-signaler, juste continuer à respecter)

1. **Graphe transitif incomplet** : `GraphBuilder` ne construit que les arêtes
   projet→dépendances directes. Les arêtes entre paquets transitifs (qui exige quoi
   sur qui) ne sont pas construites — ça demanderait de parcourir récursivement
   `PackageMetadataSource`, ce que rien ne fait encore.
2. **`ProjectAnalyzer` ne détecte pas `versionConflict` ni
   `incompatibleSdkConstraint`** directement — `versionConflict` est couvert
   séparément par `DependencyResolver` (via le vrai `pub`), pas par l'analyzer
   statique.
3. **Personne n'assemble encore un `AnalysisResult` complet** de bout en bout —
   chaque brique (`ProjectAnalyzer`, `DependencyResolver`, `IssueRecommender`,
   `FixGenerator`, `PubspecEditor`, `FixVerifier`) existe et compile isolément, mais
   l'orchestration complète n'existe que partiellement (voir `CheckCommand` dans le
   CLI, section 3 — qui ne couvre que analyzer + resolver + recommender, pas encore
   fixes/verification).
4. **Aucun test** — décision explicite, toujours active.

---

## 3. `apps/cli` — état : en cours (Phase 2)

### Fichiers créés

```
apps/cli/pubspec.yaml
  — dépendances ajoutées : fluttercheck_core (path: ../../packages/core), http

apps/cli/lib/src/services/
  pub_dev_metadata_source.dart  — implémente PackageMetadataSource via l'API pub.dev
  pub_process_runner.dart        — implémente PubRunner via Process.run('dart'/'flutter', ['pub', ...])
  project_loader.dart            — lit pubspec.yaml/lock + versions SDK installées → Project

apps/cli/lib/src/outputs/
  text_report_writer.dart        — format texte minimal (pas de JSON/couleur pour l'instant)

apps/cli/lib/src/commands/
  check_command.dart             — commande `check` : Loader → Analyzer → Resolver → Recommender → texte

apps/cli/bin/fluttercheck.dart   — point d'entrée, parsing d'arguments FAIT À LA MAIN
  (pas de package:args — décision volontaire, contrat de commandes pas encore figé)
```

### Décisions/corrections faites en cours de route

- **`ProjectLoader`** : version Dart installée déterminée différemment selon le
  contexte — pour un projet Flutter, c'est `dartSdkVersion` renvoyé par
  `flutter --version --machine` qui fait foi (pas `Platform.version`, qui reflète le
  SDK exécutant le CLI lui-même, potentiellement différent). `Platform.version`
  n'est utilisé qu'en fallback si aucun Flutter n'est trouvé sur le PATH.
  Format JSON de `flutter --version --machine` confirmé par l'utilisateur (champs
  `frameworkVersion`, `dartSdkVersion`, etc.).
- **`PubProcessRunner`** : le choix `dart` vs `flutter` comme exécutable se fait en
  regardant si le projet déclare une contrainte SDK Flutter ou dépend du paquet SDK
  `flutter`.

### Limite connue et NON résolue — à vérifier en premier dans la prochaine session

**Incertitude sur `flutter pub upgrade --dry-run`** : une issue GitHub de 2019
indiquait que le wrapper `flutter pub` ne supportait pas `--dry-run` (contrairement
à `dart pub` directement), sans confirmation trouvée que ce soit corrigé
aujourd'hui. Le code actuel suppose que ça fonctionne. **Premier test à faire** :
lancer `CheckCommand` sur un vrai projet Flutter avec un conflit connu, et vérifier
si `flutter pub upgrade --dry-run` renvoie un vrai résultat de résolution ou une
erreur d'option inconnue. Si erreur d'option : il faudra distinguer explicitement ce
cas (`PubRunnerException` plutôt qu'un `PubSolveOutcome.failed`) dans
`PubProcessRunner`.

**Autre limite assumée** : `PubSolveResult.changes` est toujours vide dans
l'implémentation actuelle de `PubProcessRunner` — aucun format texte fiable et
documenté n'a été trouvé pour parser les lignes de changement de
`pub get/upgrade --dry-run` (contrairement à `pub add --dry-run --json`, qui lui
est documenté). Seul le code de sortie (0/non-0) est utilisé comme signal.

### Point à vérifier après intégration (jamais confirmé dans cette session)

Le nom du package déclaré dans `apps/cli/pubspec.yaml` (`name: ...`) — l'import
`package:fluttercheck/src/commands/check_command.dart` dans
`bin/fluttercheck.dart` suppose que c'est `fluttercheck`. À corriger si le vrai nom
diffère.

---

## 4. Prochaine étape immédiate

Dans l'ordre, ce qui reste à faire pour boucler `check` puis avancer :

1. **Tester `CheckCommand` sur un vrai projet** (`dart run bin/fluttercheck.dart
check .` depuis `apps/cli`, sur un projet Flutter réel) — jamais fait dans
   cette session. Vérifier en particulier le point `flutter pub upgrade --dry-run`
   ci-dessus.
2. Décider si/quand ajouter une commande `fix` (assemble `FixGenerator` +
   `PubspecEditor` + `FixVerifier`, pas encore fait) — commande qui **écrit** sur
   disque, contrairement à `check`.
3. Continuer selon l'ordre des phases du doc maître (CLI → tests du Core → API →
   Web → VS Code), en gardant le principe : un sujet à la fois, décisions
   structurantes toujours validées avant d'être codées.

---

## 5. Comment démarrer la prochaine session

Donner ce document à la nouvelle session (copier-coller ou accès repo via Claude
Code), en plus du document maître du projet, avec un message du type :

> Voici le contexte de FlutterCheck. Le document maître définit la vision et les
> règles de collaboration. Ce document de passation résume l'état exact du code et
> les décisions déjà validées à ne pas rediscuter. On reprend à : tester
> `CheckCommand` sur un vrai projet.
