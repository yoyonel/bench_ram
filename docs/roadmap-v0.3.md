# Roadmap v0.3 — Containerisation Docker/Podman

> Milestone : version 0.3.0
> Branche : `feat/containerization`

## Vue d'ensemble

Intégrer une exécution containerisée complète (Docker + Podman) pour garantir la reproductibilité des benchmarks, isoler du système hôte, et permettre le multi-version testing.

Voir [docs/containerization.md](containerization.md) pour l'analyse technique détaillée.

## Tâches

### Phase 1 — Image de base et Dockerfile

- [ ] **T01** ([#7](https://github.com/yoyonel/bench_ram/issues/7)) — Écrire le `Dockerfile` multi-stage (`debian:bookworm-slim`)
  - Stage 1 : installation de tous les compilateurs/runtimes (gcc, g++, rustc, go, zig, nim, vlang, javac, python3, node, bun, ruby, php, lua, perl)
  - Stage final : image unique avec tous les toolchains prêts
  - Figer les versions via `apt-get install pkg=version` ou téléchargement direct
  - Utiliser `--mount=type=cache,target=/var/cache/apt` pour accélérer les rebuilds

- [ ] **T02** ([#8](https://github.com/yoyonel/bench_ram/issues/8)) — Écrire un `.dockerignore` propre
  - Exclure `.git/`, `results/`, `*.png`, fichiers temporaires

- [ ] **T03** ([#9](https://github.com/yoyonel/bench_ram/issues/9)) — Valider que l'image build correctement avec Docker ET Podman
  - Tester `docker build` et `podman build`
  - Documenter les éventuelles différences

### Phase 2 — Script d'orchestration conteneur

- [ ] **T04** ([#10](https://github.com/yoyonel/bench_ram/issues/10)) — Créer `scripts/container.sh` : wrapper d'exécution containerisée
  - Détection automatique `podman` > `docker` (préférer podman si disponible)
  - Build de l'image si absente ou si `--rebuild` passé
  - Montage du projet en volume (`-v $PWD:/bench:ro`)
  - Montage d'un dossier de résultats en écriture (`-v $PWD/results:/bench/results`)
  - Exécution du bench demandé à l'intérieur du conteneur
  - Usage : `./scripts/container.sh ram -n 5`, `./scripts/container.sh all`

- [ ] **T05** ([#11](https://github.com/yoyonel/bench_ram/issues/11)) — Gestion du nommage/tag de l'image
  - Tag basé sur la version : `bench_ram:0.3.0`
  - Tag `latest` pour dev
  - Détection d'image existante pour skip le build

### Phase 3 — Intégration Justfile

- [ ] **T06** ([#12](https://github.com/yoyonel/bench_ram/issues/12)) — Ajouter les recettes Justfile pour l'exécution containerisée
  - `just container-build` : build l'image
  - `just container-ram *ARGS` : bench RAM en conteneur
  - `just container-startup *ARGS` : bench startup en conteneur
  - `just container-compare *ARGS` : bench compare en conteneur
  - `just container-all *ARGS` : les trois benchmarks en conteneur
  - `just container-export *ARGS` : export résultats en conteneur
  - `just container-shell` : ouvre un shell interactif dans le conteneur (debug)
  - `just container-langs` : liste les langages disponibles dans le conteneur avec versions

### Phase 4 — Adaptation du code de mesure

- [ ] **T07** ([#13](https://github.com/yoyonel/bench_ram/issues/13)) — Vérifier/adapter `lib/measure.sh` pour fonctionner dans un conteneur
  - `/proc/[pid]/status` doit être lisible (pas de restriction PID namespace)
  - Vérifier que `kill -9` fonctionne correctement dans le namespace
  - Tester que les métriques VmRSS/RssAnon sont cohérentes avec les mesures natives

- [ ] **T08** ([#14](https://github.com/yoyonel/bench_ram/issues/14)) — Ajouter les métadonnées d'environnement dans les exports
  - Détecter si on tourne dans un conteneur (`/.dockerenv` ou cgroup)
  - Ajouter dans les JSON/CSV : `environment: "container"` ou `"native"`
  - Ajouter `kernel_version`, `container_image`, `container_runtime`

### Phase 5 — Validation et delta container vs native

- [ ] **T09** ([#15](https://github.com/yoyonel/bench_ram/issues/15)) — Script de validation : comparer résultats natif vs conteneur
  - Exécuter le bench en natif ET en conteneur
  - Calculer le delta par langage et par métrique
  - Documenter les résultats dans `docs/containerization.md` (section validation)
  - Critère d'acceptation : delta < 5% sur RssAnon pour chaque langage

- [ ] **T10** ([#16](https://github.com/yoyonel/bench_ram/issues/16)) — Tests de non-régression
  - Vérifier que les résultats container sont dans les marges attendues
  - Vérifier que `--version`, `--help`, `-n`, `-f`, `-o` fonctionnent en mode container
  - Vérifier que les exports (CSV, JSON, Markdown) sont identiques en format

### Phase 6 — Documentation et release

- [ ] **T11** ([#17](https://github.com/yoyonel/bench_ram/issues/17)) — Mettre à jour le `README.md`
  - Section "Exécution containerisée" avec exemples
  - Prérequis : Docker ou Podman
  - Explication rapide de pourquoi les résultats sont fiables en conteneur

- [ ] **T12** ([#18](https://github.com/yoyonel/bench_ram/issues/18)) — Mettre à jour `docs/architecture.md`
  - Ajouter la section architecture containerisée
  - Expliquer le flux : build image → mount volume → exec interne → export résultats

- [ ] **T13** ([#19](https://github.com/yoyonel/bench_ram/issues/19)) — Bump version à `0.3.0`
  - Mettre à jour `VERSION`
  - Tag git `v0.3.0`

## Ordre d'exécution recommandé

```
T01 → T02 → T03 (image prête)
  → T04 → T05 (orchestration)
    → T06 (justfile)
      → T07 → T08 (adaptation mesure)
        → T09 → T10 (validation)
          → T11 → T12 → T13 (docs + release)
```

## Hors scope v0.3

Les items suivants sont identifiés mais reportés à une version ultérieure :

- **Multi-version testing** (Python 3.11/3.12/3.13, GCC 12/13/14) → v0.4
- **CI/CD GitHub Actions** avec exécution containerisée → v0.4
- **Image Alpine séparée** pour comparaison musl vs glibc → v0.4
- **Matrice de versions** (benchmark croisé versions × langages) → v0.5
