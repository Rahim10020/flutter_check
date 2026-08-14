# FlutterCheck — Contexte pour agents IA (à lire avant toute tâche)

Ce fichier s'adresse à tout agent/assistant IA travaillant sur ce repository
(Kilo Code, GitHub Copilot, Codex, ou autre). Il doit être lu et respecté
avant toute modification de code, même mineure.

---

## 1. Ce qu'est FlutterCheck, en une phrase

Un outil qui analyse un projet Flutter/Dart, détecte les incompatibilités de
versions entre le SDK et les dépendances, explique pourquoi, et recommande —
un jour, automatise — des corrections fiables. Pas un simple "cette version
est incompatible" : un assistant qui comprend l'état réel d'un projet et
aide à le résoudre.

**La fiabilité prime sur tout le reste.** Il vaut mieux dire "je ne peux pas
déterminer de solution fiable" que proposer une version qui pourrait casser
le projet d'un développeur. FlutterCheck ne réimplémente jamais la logique
de résolution de Pub (pas de PubGrub maison) — il délègue toujours à un
vrai process `pub` et interprète son résultat.

---

## 2. Architecture (ne pas rediscuter, ne pas "corriger")

Monorepo, dossiers racine préfixés `_apps/` et `_packages/` (choix
délibéré, pas une erreur) :

```
_apps/api/    (Dart, Shelf — non commencé)
_apps/cli/    (Dart — en cours)
_apps/web/    (Next.js/TS — non commencé)
_packages/core/  (Dart — le moteur, source de vérité, structurellement complet)
```

Principe non négociable : **toute la logique métier vit dans `core`**. Le
CLI, l'API et le Web ne font qu'appeler le Core — jamais de logique de
résolution ou d'analyse dupliquée dans une interface.

Le Core définit des interfaces abstraites pour tout ce qui touche à l'I/O
(réseau, filesystem, subprocess) — `PubRunner`, `PackageMetadataSource`,
`ProjectWorkspace`, `LockfileSandbox`. Les implémentations concrètes vivent
dans les apps (CLI pour l'instant). **Ne jamais faire d'I/O directement
dans `_packages/core`.**

Ordre de développement (ne pas sauter d'étape) :
Phase 0 Architecture/Research → **Phase 1 Core (structurellement fait)** →
**Phase 2 CLI (en cours)** → Phase 3 Tests Core → Phase 4 API → Phase 5 Web
→ Phase 6 Intégration → Phase 7 VS Code (volontairement en dernier).

---

## 3. Règles de collaboration — à respecter STRICTEMENT

- **Ne jamais prendre de décision structurante sans validation explicite** :
  changement de stack, nouvelle dépendance majeure, changement de stratégie
  de résolution, changement de contrat entre Core/CLI/API, suppression de
  code existant. Si une tâche semble en impliquer une, **s'arrêter et
  demander**, ne pas trancher seul.
- **Pas de tests pour l'instant** — décision explicite et toujours active.
  Ne pas ajouter de fichiers de test sans qu'on le demande.
- **Un sujet à la fois.** Ne pas élargir le scope d'une tâche de correction
  de bug en refactoring, ni l'inverse.
- **Pour une tâche de correction d'erreurs de compilation/type** : corriger
  uniquement ce qui est nécessaire pour que ça compile — ne pas changer les
  noms de méthodes, les signatures de contrats, ni l'architecture, sauf si
  explicitement demandé. Si l'erreur révèle qu'un vrai changement
  structurel est nécessaire (pas juste mécanique), le signaler plutôt que
  de le faire silencieusement.
- **N'ajouter aucune dépendance** sans qu'elle soit explicitement demandée
  ou validée dans ce document.

---

## 4. Vérifier les informations à jour — ne pas se fier à la mémoire d'entraînement

**Nous sommes en 2026.** Les modèles de langage (y compris cet agent) ont
des données d'entraînement qui peuvent dater d'avant des changements de
comportement de Pub, Dart, Flutter, ou de leurs outils CLI.

Exemple concret déjà rencontré dans ce projet : une issue GitHub de 2019
indiquait que `flutter pub upgrade --dry-run` n'était pas supporté — testé
en 2026 sur ce projet, **ce n'est plus vrai**, l'option fonctionne
normalement. Une IA qui se serait fiée à sa mémoire d'entraînement aurait
codé un contournement inutile pour un problème qui n'existe plus.

**Règle : avant toute décision technique qui dépend du comportement actuel
de `pub`, Dart SDK, Flutter SDK, ou de leurs formats de sortie/API — ne pas
supposer à partir de la mémoire d'entraînement seule.** Si l'agent a accès
à une recherche web, vérifier l'information à jour. Sinon, signaler
explicitement l'incertitude et proposer un test manuel (comme on l'a fait
pour `--dry-run`) plutôt que de coder sur une hypothèse non vérifiée.

---

## 5. État actuel du projet (mise à jour manuelle après chaque session)

### Core (`_packages/core`) — structurellement complet

Toutes les couches existent et compilent : models, parsers, dependencies,
graph (arêtes directes seulement — pas encore transitif), analyzer,
recommendations, fixes (infrastructure présente, pas encore branchée),
verification, resolver.

Décisions figées : `pub_semver` et `yaml`/`yaml_edit` (packages officiels
Dart) pour SemVer et parsing YAML. Accès pub.dev et accès à `pub` toujours
via interfaces abstraites (`PackageMetadataSource`, `PubRunner`),
implémentées côté CLI.

### CLI (`_apps/cli`) — en cours

`ProjectLoader`, `PubDevMetadataSource`, `PubProcessRunner`, `CheckCommand`
existent et ont été testés sur un vrai projet Flutter (`chatapp`) — `check`
fonctionne bout en bout, rapport cohérent, pas de crash.

### Resolver — V1 en cours d'implémentation

Problème résolu : `PubSolveResult.changes` était toujours vide (aucun
format fiable pour parser la sortie texte de `pub --dry-run`), ce qui
empêchait de produire des `Recommendation` actionnables même quand un
conflit était résolvable.

Solution retenue : **diff de `pubspec.lock` avant/après**, dans une copie
temporaire du projet (jamais le projet original), en rejouant la commande
réelle correspondant exactement au dry-run qui a prouvé le succès —
jamais une commande différente choisie heuristiquement.

Nouveaux contrats Core ajoutés :

- `ProjectWorkspace` — copie temporaire (`pubspec.yaml` + `pubspec.lock`
  uniquement, pas tout le projet) avec nettoyage garanti (`try/finally`).
- `LockfileSandbox` — orchestre : lock avant → rejoue la vraie commande
  pub dans la copie → lock après → diff structuré en `PubDependencyChange`.
- Mapping dry-run → commande réelle centralisé dans `RealPubCommand`
  (`getDryRun`→`pub get`, `upgradeDryRun`→`pub upgrade`).
  `upgradeMajorVersionsDryRun` **explicitement hors scope V1** — lève une
  erreur si appelé, ne pas l'implémenter sans validation préalable.
- `PubDependencyChange` refondu avec `ChangeKind` explicite
  (`added`/`removed`/`changed`) plutôt que des champs nullables ambigus.

Le sandbox n'est déclenché **que** quand `getDryRun` échoue et que
`upgradeDryRun` réussit — jamais dans le cas nominal (`getDryRun` réussi),
pour ne pas payer le coût d'une résolution réelle quand rien n'a besoin
d'être recommandé.

**Statut à cette date** : le code vient d'être ajouté et les erreurs de
compilation initiales ont été corrigées. Prochaine étape : test terrain
sur un vrai conflit de dépendances pour valider que le flux complet
(conflit → sandbox → diff → Recommendation) produit un résultat correct.

### Commande `fix` — décision actée, non implémentée

Pas de `fix` v1 limité à `outOfSyncLockfile` (jugé non différenciant, pub
le fait déjà). Priorité au Resolver pour produire de vraies recommandations
de versions fiables avant de construire `fix`.

Modèle cible validé pour plus tard (ne pas coder avant nouvelle validation
explicite) : séparation `FixTarget` (Dependency/Project/Sdk/File-futur) et
`FixAction` type-safe (`UpdateConstraintAction`, `RemoveDependencyAction`,
`AddOverrideAction`, `RegenerateLockfileAction`), chaque action portant
directement ses propres données — pas de `Fix` générique à champs
optionnels. `SdkTarget` n'a et n'aura jamais d'action de fix exécutable :
FlutterCheck ne modifie jamais une installation de SDK.

---

## 6. Comment mettre à jour ce fichier

Après une session de travail qui change l'état du projet (nouvelle
décision structurante, nouvelle brique codée, nouveau statut d'une phase),
mettre à jour la section 5 en conséquence. Ne pas laisser ce fichier devenir
obsolète — un agent qui s'y fie pour éviter de redemander des décisions
déjà prises a besoin qu'il reflète l'état réel.
