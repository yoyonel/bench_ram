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

### Options

| Flag | Description | Défaut |
|------|-------------|--------|
| `-n <N>` | Nombre de runs par langage (médiane retenue) | `5` |
| `-f <flags>` | Flags de compilation passés aux compilateurs | Défaut par langage |

## Exemple de sortie

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

Les résultats sont triés par **RssAnon croissant** (le plus léger en premier).

## Prérequis

- Linux (nécessite `/proc/[pid]/status`)
- Bash 4+
- Les compilateurs/interprètes des langages à tester

## Structure du projet

```
bench_ram/
├── bench_ram.sh          # Orchestrateur principal
├── lib/
│   ├── measure.sh        # Moteur de mesure (poll, stabilisation, médiane)
│   └── utils.sh          # Utilitaires (check_cmd, median, formatage)
├── langs/                # Un fichier par langage
│   ├── c.sh
│   ├── cpp.sh
│   ├── rust.sh
│   └── ...
└── docs/
    └── architecture.md   # Choix techniques et méthodologie
```

## Ajouter un langage

Créer un fichier `langs/<lang>.sh` avec cette structure :

```bash
#!/bin/bash
lang_name="MonLangage"
lang_cmd="moncompilateur"  # Commande vérifiée par check_cmd

lang_prepare() {
    local ws="$1" flags="${2:--O2}"
    # Écrire le source et compiler dans $ws
}

lang_write_runner() {
    local ws="$1"
    echo '#!/bin/bash' > "$ws/run.sh"
    echo "exec \"$ws/mon_binaire\"" >> "$ws/run.sh"
}
```

Le fichier est auto-découvert par l'orchestrateur — aucune modification de `bench_ram.sh` nécessaire.
