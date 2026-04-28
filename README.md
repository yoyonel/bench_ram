# bench_ram

Benchmark de l'empreinte RAM minimale absolue de différents langages de programmation sous Linux.

## Principe

Un seul programme par langage : **une boucle infinie**. Rien d'autre. Pas de HTTP, pas d'I/O, pas de librairie. L'objectif est de mesurer le coût incompressible du runtime lui-même — ce que le langage consomme avant même de faire quoi que ce soit d'utile.

Les métriques sont lues directement depuis `/proc/[pid]/status` :

| Métrique | Signification |
|----------|---------------|
| **VmSize** | Mémoire virtuelle totale allouée (inclut le code, heap, stack, mmap, libs partagées) |
| **VmRSS** | Resident Set Size — pages effectivement en RAM physique (inclut les libs partagées) |
| **RssAnon** | Pages anonymes résidentes — **mémoire exclusive** au processus (heap, stack, hors `.so`) |

**RssAnon est la métrique principale.** C'est la seule qui isole la consommation propre du runtime en excluant les pages partagées du système (libc, ld-linux, etc.).

## Langages supportés

**Compilés :** C, C++, Rust, Go, Zig, Nim, V
**Interprétés :** Python, Node.js, Ruby, PHP, Lua, Perl, Bun
**JVM :** Java

Les langages dont le toolchain n'est pas installé sont automatiquement ignorés.

## Usage

### Benchmark RAM (principal)

```bash
# Exécution par défaut (5 runs, flags par défaut)
./bench_ram.sh

# Changer le nombre de répétitions
./bench_ram.sh -n 3

# Forcer des flags de compilation
./bench_ram.sh -f "-O3"
./bench_ram.sh -f "-O0"
./bench_ram.sh -f "-O2 -static"

# Combiné
./bench_ram.sh -n 10 -f "-O3"
```

### Benchmark startup time

Mesure le temps de démarrage (cold-start) de chaque langage via un programme qui exit immédiatement.

```bash
./bench_startup.sh           # 5 runs par défaut
./bench_startup.sh -n 10     # 10 runs pour plus de précision
./bench_startup.sh -f "-O3"  # Avec flags de compilation
```

### Benchmark comparatif (debug/release/static/stripped)

Compare l'empreinte RAM selon le profil de compilation pour les langages compilés.

```bash
./bench_compare.sh           # 3 runs par profil
./bench_compare.sh -n 5      # 5 runs par profil
```

### Options

| Flag | Description | Défaut |
|------|-------------|--------|
| `-n <N>` | Nombre de runs par langage (médiane retenue) | `5` |
| `-f <flags>` | Flags de compilation passés aux compilateurs | Défaut par langage |
| `-o <dir>` | Exporter les résultats (CSV, JSON, Markdown) dans ce répertoire | Désactivé |
| `--version` | Afficher la version | — |

### Export des résultats

```bash
# Exporter CSV + JSON + Markdown dans results/
./bench_ram.sh -o results
./bench_startup.sh -o results

# Générer un graphique ASCII à partir du dernier export
just plot-ram
just plot-startup

# Générer des PNG (nécessite matplotlib)
pip install matplotlib
just plot-png
```

## Exécution en conteneur (Docker / Podman)

L'ensemble des 15 toolchains est pré-installé dans une image Docker basée sur `debian:bookworm-slim`. Aucune installation locale n'est requise.

```bash
# Construire l'image (automatique au premier run)
just container-build

# Benchmarks
just container-ram               # RAM uniquement
just container-startup           # Startup uniquement
just container-compare           # Comparatif debug/release/static/stripped
just container-all               # Les 3 benchmarks
just container-all -- -n 3       # Avec options (3 runs)

# Export des résultats dans results/
just container-export

# Outils
just container-langs             # Versions des toolchains dans l'image
just container-shell             # Shell interactif dans le conteneur

# Validation: delta container vs natif (< 5% sur RssAnon)
just container-validate          # 3 runs par défaut
just container-validate -- -n 5  # 5 runs pour plus de précision
```

L'image utilise **glibc** (pas musl/Alpine) pour que les mesures RAM soient identiques à celles en natif. Le runtime est auto-détecté (Podman prioritaire, puis Docker). Voir [docs/containerization.md](docs/containerization.md) pour l'analyse détaillée.

## Exemple de sortie

### bench_ram.sh

```
Langage      |  VmSize (Virt) |  VmRSS (Total) | RssAnon (Excl)
-----------------------------------------------------------------------
C            |      2424 kB |      1296 kB |       100 kB
C++          |      2424 kB |      1340 kB |       104 kB
Rust         |      3068 kB |      1936 kB |       124 kB
Lua          |      4288 kB |      2160 kB |       208 kB
Perl         |     10724 kB |      5384 kB |       464 kB
Go           |   1225036 kB |      3228 kB |      2248 kB
Python       |     17764 kB |     11000 kB |      4336 kB
Ruby         |    469856 kB |     19296 kB |     13524 kB
Node.js      |   1428792 kB |     58680 kB |     13704 kB
```

### bench_startup.sh

```
Langage      |  Startup (µs) |   Startup (ms)
---------------------------------------------
C            |        0 µs |      0.00 ms
Rust         |        0 µs |      0.00 ms
C++          |      233 µs |      0.23 ms
Go           |      407 µs |      0.41 ms
Lua          |     1359 µs |      1.36 ms
Perl         |     2747 µs |      2.75 ms
Ruby         |   206468 µs |    206.47 ms
Node.js      |   251925 µs |    251.93 ms
Python       |   282479 µs |    282.48 ms
```

### bench_compare.sh

```
Langage      |      debug |    release |     static |   stripped
------------------------------------------------------------------------
C            |      100 kB |      100 kB |       52 kB |      104 kB
C++          |      100 kB |      104 kB |       56 kB |      100 kB
Rust         |      124 kB |      124 kB |       80 kB |      128 kB
Go           |     2244 kB |     2248 kB |     2248 kB |     2248 kB
```

Les résultats sont triés par **RssAnon croissant** (le plus léger en premier).

## Prérequis

- Linux (nécessite `/proc/[pid]/status`)
- Bash 4+
- **Mode natif :** les compilateurs/interprètes des langages à tester
- **Mode conteneur :** Docker ou Podman (les 15 toolchains sont dans l'image)

## Structure du projet

```
bench_ram/
├── bench_ram.sh          # Benchmark RAM (principal)
├── bench_startup.sh      # Benchmark temps de démarrage
├── bench_compare.sh      # Comparatif debug/release/static/stripped
├── Justfile              # Tâches (just --list pour voir les recettes)
├── Dockerfile            # Image multi-toolchains (15 langages)
├── .dockerignore         # Exclusions pour le build context
├── VERSION               # Version semver du projet
├── lib/
│   ├── engine.sh         # Moteur commun (init, itération langages, cleanup)
│   ├── measure.sh        # Moteur de mesure RAM (poll, stabilisation, médiane)
│   ├── startup.sh        # Moteur de mesure startup time
│   ├── export.sh         # Export schema-driven CSV / JSON / Markdown
│   └── utils.sh          # Utilitaires (check_cmd, median, formatage)
├── scripts/
│   ├── container.sh      # Orchestration Docker/Podman
│   ├── validate_delta.sh # Validation delta container vs natif
│   ├── test_container.sh # Tests de non-régression conteneur
│   └── plot.py           # Génération de graphiques (ASCII ou PNG via matplotlib)
├── langs/                # Un fichier par langage (RAM + startup + compare)
│   ├── c.sh
│   ├── cpp.sh
│   ├── rust.sh
│   └── ...
├── results/              # Exports générés (gitignored)
├── docs/
│   ├── architecture.md       # Choix techniques et méthodologie
│   ├── containerization.md   # Analyse conteneurisation (overhead, image, musl vs glibc)
│   └── roadmap-v0.3.md       # Roadmap v0.3
├── .github/
│   └── workflows/ci.yml  # CI GitHub Actions (shellcheck + shfmt)
├── .pre-commit-config.yaml
├── .shellcheckrc
└── .editorconfig
```

## Développement

### Lint & format

```bash
just lint          # Analyse statique (shellcheck)
just format-check  # Vérification du formatage (shfmt, pas de modification)
just format        # Auto-formatage en place
just ci            # lint + format-check
```

Les mêmes vérifications tournent automatiquement :
- **Pre-commit hooks** : bloquent le commit si lint/format échoue
- **GitHub Actions** : sur push/PR vers master/main

### Recettes utilitaires

```bash
just langs         # Liste les toolchains installés/manquants avec versions
just check         # Vérifie que les scripts sont exécutables
just tree          # Affiche la structure du projet
```

## Ajouter un langage

Créer un fichier `langs/<lang>.sh` avec cette structure :

```bash
#!/bin/bash
lang_name="MonLangage"
lang_cmd="moncompilateur"  # Commande vérifiée par check_cmd
lang_type="compiled"       # "compiled" ou "interpreted"

# (Optionnel, langages compilés) Flags par profil pour bench_compare
lang_compare_flags() {
    local profile="$1"
    case "$profile" in
        debug) echo "-O0 -g" ;;
        release) echo "-O2" ;;
        static) echo "-O2 -static" ;;
        stripped) echo "-O2 -s" ;;
    esac
}

# RAM benchmark — boucle infinie
lang_prepare() {
    local ws="$1" flags="${2:--O2}"
    # Écrire le source et compiler dans $ws
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec \"$ws/mon_binaire\"" >> "$ws/run.sh"
}

# Startup benchmark — exit immédiat
lang_startup_prepare() {
    local ws="$1" flags="${2:--O2}"
    # Écrire le source et compiler dans $ws
}

lang_startup_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/startup_run.sh"
    echo "exec \"$ws/mon_binaire_startup\"" >> "$ws/startup_run.sh"
}
```

Le fichier est auto-découvert par le moteur — aucune modification des orchestrateurs nécessaire.
