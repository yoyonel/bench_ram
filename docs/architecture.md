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

