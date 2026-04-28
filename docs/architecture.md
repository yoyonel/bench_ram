# Architecture et méthodologie

## Philosophie du benchmark

**Un seul programme : une boucle infinie.** Ce choix est délibéré et non-négociable.

L'objectif n'est pas de mesurer les performances d'un programme réaliste, mais d'isoler le **coût incompressible du runtime** de chaque langage. Une boucle infinie est le programme le plus simple possible qui maintient un processus vivant sans effectuer aucune allocation dynamique, aucun I/O, aucun syscall au-delà de l'initialisation.

Cela permet de répondre à la question : *"Combien de RAM un langage consomme-t-il juste pour exister ?"*

## Choix de la source de données : `/proc/[pid]/status`

### Pourquoi pas `ps`, `top`, `/proc/[pid]/smaps` ?

| Outil | Problème |
|-------|----------|
| `ps aux` | Parse la sortie de `procfs` indirectement, arrondit, n'expose pas RssAnon |
| `top` / `htop` | Interactif, overhead, rafraîchissement non déterministe |
| `/proc/[pid]/smaps` | Plus détaillé mais plus coûteux à parser (une entrée par mapping) |
| `/proc/[pid]/statm` | Valeurs en pages, pas de RssAnon |

**`/proc/[pid]/status`** offre le meilleur compromis : lecture atomique du kernel, toutes les métriques nécessaires en un seul fichier, pas de parsing complexe.

### Métriques retenues

- **VmSize** : mémoire virtuelle totale. Inclut tout ce qui est mappé (code, heap, stack, shared libs, reserves). Utile pour comprendre l'address space, mais pas la consommation réelle.
- **VmRSS** : pages résidentes en RAM physique. Inclut les pages partagées (libc, ld-linux). Un processus peut avoir un VmRSS élevé dont 90% est partagé avec d'autres processus.
- **RssAnon** : pages anonymes résidentes. C'est la heap + stack du processus, **exclusive à ce processus**. C'est la métrique qui répond à "combien ce runtime coûte EN PLUS du système de base".

## Stabilisation de la mesure

### Problème

Quand un processus démarre, sa mémoire évolue pendant l'initialisation du runtime (chargement des `.so`, setup du GC, création de threads internes, etc.). Mesurer trop tôt capture un état transitoire.

### Solution : poll avec convergence

Au lieu d'un `sleep` fixe (arbitraire et insuffisant pour les runtimes lourds) :

1. Lire VmRSS toutes les **100ms**
2. Calculer le delta avec la lecture précédente
3. Considérer la mesure stable quand **3 lectures consécutives** ont un delta < **64 kB**
4. Timeout à **10 secondes** (pour les runtimes qui n'arrêtent jamais d'allouer)

Les seuils sont configurables en tête de `lib/measure.sh`.

### Pourquoi 64 kB comme seuil ?

C'est 16 pages mémoire (4 kB chacune). Suffisamment petit pour détecter la fin de l'initialisation, suffisamment grand pour ignorer le bruit du kernel (pages de garde, TLB, etc.).

## Répétitions et médiane

Chaque langage est mesuré **N fois** (défaut 5). La médiane est retenue (pas la moyenne) car elle est résistante aux outliers :
- Un CPU throttle sur un run → ignoré
- Un GC kick sur un run → ignoré
- Le kernel qui fait du background reclaim → ignoré

## Architecture du code

### Moteur commun (`lib/engine.sh`)

Les trois orchestrateurs (`bench_ram.sh`, `bench_startup.sh`, `bench_compare.sh`) partagent un moteur commun qui factorise :

- **`engine_init`** : parsing des arguments (`-n`, `-f`, `-o`), gestion de `--version`/`--help`, création d'un workspace temporaire isolé par PID (`/tmp/bench_workspace_$$`), sourcing des librairies communes.
- **`engine_iterate_langs`** : boucle sur `langs/*.sh`, reset des fonctions et variables entre chaque adaptateur (`unset -f`), source l'adaptateur, vérifie la disponibilité du toolchain (`check_cmd`), puis appelle un callback défini par l'orchestrateur.
- **`engine_finish`** : export des résultats via `export_all` puis nettoyage du workspace.

Chaque orchestrateur se réduit à ~50 lignes : init, définition du callback, itération, affichage, finish.

### Adaptateurs auto-descriptifs (`langs/*.sh`)

Chaque fichier `langs/*.sh` est un adaptateur autonome qui déclare :

**Métadonnées :**
- `lang_name` : nom d'affichage (ex: `"C"`, `"Rust"`)
- `lang_cmd` : commande vérifiée par `check_cmd` (ex: `"gcc"`, `"rustc"`)
- `lang_type` : `"compiled"` ou `"interpreted"` — utilisé par `bench_compare.sh` pour savoir si les profils de compilation s'appliquent

**Fonctions RAM :**
- `lang_prepare <ws> [flags]` : écrit le source et compile dans le workspace
- `lang_write_runner <ws>` : écrit `run.sh` avec `exec`

**Fonctions startup :**
- `lang_startup_prepare <ws> [flags]` : prépare un programme qui exit immédiatement
- `lang_startup_runner <ws>` : écrit le runner startup

**Fonction compare (optionnelle, langages compilés) :**
- `lang_compare_flags <profile>` : retourne les flags pour un profil donné (`debug`, `release`, `static`, `stripped`). Si absente, des flags par défaut gcc-style sont utilisés.

Avant la v0.2, les fonctions startup vivaient dans un dossier séparé `langs/startup/*.sh` (15 fichiers dupliqués). Elles sont maintenant fusionnées dans l'adaptateur principal — un seul fichier par langage, pas de duplication.

### Export schema-driven (`lib/export.sh`)

L'export utilise trois writers génériques (`_export_csv`, `_export_json`, `_export_md`) pilotés par un schéma déclaré dans `export_all` :

```
export_all <type> <output_dir> <results...>
```

Le schéma (noms de champs, types `s`=string / `n`=number) est défini par type de benchmark. Les writers n'ont aucune connaissance du domaine — ils itèrent sur les champs et appliquent le typage :
- CSV : header + valeurs séparées par virgules
- JSON : objets typés (`"N/A"` → `null`, numériques sans quotes)
- Markdown : header + lignes formatées par une fonction de rendu spécifique au type

### Pourquoi découper en `langs/*.sh` ?

- **Extensibilité** : ajouter un langage = créer un fichier. Pas de modification de l'orchestrateur.
- **Auto-discovery** : le glob `langs/*.sh` détecte tout automatiquement.
- **Isolation** : chaque fichier est sourcé indépendamment, les fonctions sont `unset` entre chaque langage.
- **Testabilité** : on peut tester un langage en isolation.

### Pourquoi `exec` dans les runners ?

Chaque `langs/*.sh` écrit un script `run.sh` qui fait `exec <command>`. L'`exec` est critique :
- Sans `exec` : le PID mesuré est celui de bash (`/bin/bash run.sh`), pas celui du programme.
- Avec `exec` : bash est remplacé par le programme cible, le PID est directement celui qu'on mesure.
- Résultat : VmRSS et RssAnon reflètent le programme, pas un wrapper.

### Pourquoi Go utilise `runtime.LockOSThread()` ?

Le scheduler Go crée par défaut autant de threads OS qu'il y a de cœurs (`GOMAXPROCS`). Un `for {}` sans `LockOSThread` peut spinner sur plusieurs threads, ce qui biaise la comparaison avec des langages single-threaded. Le `LockOSThread` force le main goroutine sur un seul OS thread pour une comparaison équitable.

Note : la RAM Go reste élevée même avec un seul thread à cause du GC runtime + stack management pré-alloués.

## Flags de compilation

L'option `-f` permet de tester l'impact des flags sur la RAM :

| Flag | Effet attendu sur la RAM |
|------|--------------------------|
| `-O0` | Baseline debug — pas d'inlining, pas d'élimination de code mort |
| `-O2` | Défaut raisonnable — le compilateur optimise taille + vitesse |
| `-O3` | Agressif — peut augmenter la taille du code (loop unrolling) mais pas forcément la RAM |
| `-Os` | Optimise pour la taille — peut réduire VmSize |
| `-static` | Lie statiquement — élimine les `.so` mais augmente le binaire et potentiellement VmRSS |

En pratique, pour une boucle infinie, l'impact est minimal car il n'y a pas de code à optimiser. La différence se voit surtout sur `VmSize` (taille du segment `.text`).

## Tri des résultats

Les résultats sont triés par **RssAnon croissant**. C'est la métrique la plus pertinente pour comparer l'overhead intrinsèque des runtimes. VmSize et VmRSS sont affichés pour contexte mais ne servent pas au classement.

## Limitations connues

- **ASLR** : l'Address Space Layout Randomization peut faire varier VmSize de quelques pages entre runs. N'affecte pas RssAnon.
- **cgroups** : si le système utilise des cgroups avec memory limits, les mesures restent valides mais ne sont pas comparables entre machines.
- **Huge pages** : si le kernel utilise transparent huge pages (THP), RssAnon peut être arrondi à 2 MB. Vérifier avec `cat /sys/kernel/mm/transparent_hugepage/enabled`.
- **Java** : le source-file launch mode (`java File.java`) inclut le compilateur dans le processus. Pour une mesure plus précise, on pourrait pré-compiler et lancer `java -cp . Loop`. Mais cela reflète l'usage réel (le dev tape `java File.java`).

## Mesure du temps de démarrage (`bench_startup.sh`)

### Méthodologie

Le startup time est mesuré via wall-clock : on capture `date +%s%N` (nanosecond precision) avant et après l'exécution d'un programme qui exit immédiatement. La différence donne le temps total : fork + exec + loader + runtime init + exit.

### Calibration du shell overhead

Un wrapper bash (`run.sh` avec `exec`) ajoute un overhead incompressible (~10ms). Pour l'isoler :
1. On mesure d'abord le temps de `exec true` (programme le plus rapide possible)
2. Ce temps est soustrait de toutes les mesures
3. Si un langage est plus rapide que le shell overhead, il apparaît à 0µs

Cela signifie que les résultats < 1ms sont dans la marge d'erreur et effectivement "instantanés" du point de vue du system.

### Ce que ça mesure vraiment

Pour un binaire compilé : temps de `execve()` → dynamic linker → `_start` → `main()` → `exit()`.
Pour un interprète : tout ça + parsing du runtime + initialisation du GC/VM + interprétation du code vide.

## Comparaison de profils (`bench_compare.sh`)

### Profils testés

Chaque langage compilé déclare ses flags via `lang_compare_flags <profile>` dans son adaptateur. Les langages sans cette fonction utilisent un fallback gcc-style (`DEFAULT_PROFILES`).

| Profil | Flags C/C++ | Flags Rust | Ce que ça teste |
|--------|-------------|-----------|-----------------|
| **debug** | `-O0 -g` | `-C opt-level=0 -g` | Baseline sans optimisation, avec symboles debug |
| **release** | `-O2` | `-C opt-level=2` | Optimisations standard |
| **static** | `-O2 -static` | `-C opt-level=2 -C target-feature=+crt-static` | Linkage statique, pas de `.so` |
| **stripped** | `-O2 -s` | `-C opt-level=2 -C strip=symbols` | Symboles retirés |

### Pourquoi Go est invariant ?

Go lie toujours statiquement son runtime (pas de `libgo.so`). Les flags `-static` et `-s` n'ont pas d'impact significatif car le runtime Go pré-alloue toujours la même quantité de heap pour le GC et le stack management.

### Pourquoi static réduit RssAnon ?

Contre-intuitif : le binaire est plus gros, mais RssAnon baisse. Explication :
- En dynamic, le loader (`ld-linux.so`) alloue des structures anonymes pour résoudre les symboles (GOT, PLT, relocation tables).
- En static, il n'y a pas de loader overhead. Le binaire est auto-suffisant.
- Le `.text` plus gros apparaît dans VmSize mais pas dans RssAnon (c'est du file-backed mapping, pas anonyme).

### Langages interprétés

Les flags de compilation ne s'appliquent pas — l'interprète est déjà compilé par le système. La valeur est affichée une seule fois pour référence.

## Conteneurisation (Docker / Podman)

### Pourquoi conteneuriser ?

Le mode natif nécessite l'installation manuelle des 15 toolchains. Selon la distribution, certains langages (Zig, Nim, V, Bun) requièrent des PPA ou des installations manuelles. Le conteneur résout ce problème : une seule commande, résultats reproductibles.

### Choix de l'image de base : `debian:bookworm-slim`

| Option | Verdict | Raison |
|--------|---------|--------|
| **Alpine** | Rejeté | musl libc change fondamentalement les mesures RAM (5-10x différence sur malloc/mmap). Le benchmark mesure le runtime, pas la libc. |
| **Ubuntu** | Possible | Mais plus lourd, pas de valeur ajoutée par rapport à Debian pour ce use-case. |
| **debian:bookworm-slim** | Retenu | glibc (même mesures que natif), ~80 MB, packages stables, bon support des 15 toolchains. |

### Overhead conteneur

L'overhead Docker/Podman sur les mesures RAM est **nul** — les conteneurs Linux utilisent les mêmes namespaces, le même `/proc/[pid]/status`, le même kernel. Les process-level metrics (VmRSS, RssAnon) ne sont pas affectées par la conteneurisation car ce ne sont pas des VMs.

### Architecture du wrapper (`scripts/container.sh`)

Le script d'orchestration :
1. **Auto-détecte** le runtime (Podman prioritaire, puis Docker)
2. **Monte** le projet en read-only (`/bench:ro`) avec `results/` en read-write
3. **Passe** les variables d'environnement `BENCH_CONTAINER_IMAGE` et `BENCH_CONTAINER_RUNTIME` pour la détection dans les exports
4. **Dispatch** les commandes vers les scripts de benchmark dans le conteneur

### Métadonnées d'environnement dans les exports

Quand les benchmarks sont exécutés en conteneur, les exports incluent automatiquement :

**JSON** — structure wrappée :
```json
{
  "metadata": {
    "benchmark_type": "ram",
    "timestamp": "2026-04-28T14:03:47+00:00",
    "version": "0.2.0",
    "environment": "container",
    "kernel_version": "6.12.73+deb13-amd64",
    "container_image": "bench_ram:0.2.0",
    "container_runtime": "podman"
  },
  "results": [...]
}
```

**CSV** — ligne de commentaire préfixée par `#` :
```
# benchmark_type=ram;timestamp=...;environment=container;container_image=bench_ram:0.2.0;...
language,vmsize_kb,vmrss_kb,rssanon_kb
```

En mode natif, les champs `container_*` sont absents et `environment=native`.

### Adaptateurs modifiés pour le conteneur

Trois langages nécessitaient des corrections pour fonctionner dans l'environnement conteneur :

- **Java** : `java -cp "$ws" Loop` au lieu du source-file mode (incompatible avec `-cp`)
- **Bun** : `bun -e 'process.exit(0)'` au lieu de `bun -e ''` (chaîne vide déclenche l'aide)
- **Nim** : chemin absolu pour `-o:` (le chemin relatif résolvait dans `/bench/` monté en read-only)

