# Containerisation — Analyse et recommandations

> Analyse réalisée le 2026-04-28. Cible : intégration Docker/Podman pour bench_ram v0.3.

## Contexte

bench_ram mesure le coût incompressible du runtime de chaque langage via `/proc/[pid]/status`. La question centrale : un conteneur introduit-il un biais sur ces mesures ?

## Docker vs Podman

| Critère | Docker | Podman |
|---------|--------|--------|
| Architecture | Daemon (`dockerd` + `containerd`) permanent | Daemonless, fork/exec direct |
| Exécution par défaut | Root (rootful) | Rootless (user namespaces) |
| Overhead mémoire permanent | ~30-60 MB (daemon + containerd + shim) | 0 quand rien ne tourne |
| CLI | Référence | Drop-in (`alias docker=podman`) |
| PID namespace | Oui | Oui |
| `/proc` dans le conteneur | OK | OK |
| Format d'images | OCI | OCI (même format) |

**Recommandation** : supporter les deux. L'outil de bench détecte `podman` ou `docker` et utilise ce qui est disponible. Podman est légèrement préférable (pas de daemon résident) mais en pratique les résultats de benchmark sont identiques.

## Overhead conteneur — impact sur les mesures

### Pourquoi l'overhead est nul

Les conteneurs Linux ne sont PAS des VMs. Un process dans un conteneur est un process Linux normal avec des namespaces (PID, mount, network). Le kernel est partagé.

| Métrique | Impact conteneur | Explication |
|----------|-----------------|-------------|
| **VmRSS** | **~0** | Pages résidentes réelles. Le kernel les compte identiquement dans ou hors namespace. |
| **VmSize** | **~0** | Address space mappé. Identique. |
| **RssAnon** | **~0** | Pages anonymes (heap+stack). Strictement identique. |
| **Startup time** | **~0** si mesuré depuis l'intérieur | `exec` est un syscall normal dans ou hors namespace. |

### Subtilités mineures

1. **Overlay filesystem** : les `.so` sont chargées depuis l'overlayfs. Micro-différences de page cache possibles mais négligeables (< 1 page).
2. **cgroup memory accounting** : quelques octets de metadata kernel, mais invisibles dans les métriques userspace du process.
3. **PID namespace** : `/proc/[pid]/status` à l'intérieur montre le PID namespacé. Métriques mémoire identiques.

### Piège à éviter : architecture d'exécution

- **Correct** : démarrer le conteneur UNE fois, exécuter tous les benchmarks à l'intérieur.
- **Incorrect** : un `docker run` par mesure de startup → overhead de 100-500ms qui noie la mesure (un startup C prend ~50-200µs).

## Le piège critique : musl vs glibc

Le coût incompressible du runtime dépend **fondamentalement** de la libc.

| Aspect | glibc | musl |
|--------|-------|------|
| Allocateur | `ptmalloc2` (arenas, thread-cache) | `mallocng` (simple) |
| Stack par défaut | ~8 MB (NPTL) | ~128 KB |
| `VmSize` C `while(1)` | ~2-3 MB | ~200-400 KB |
| `VmRSS` C `while(1)` | ~1-2 MB | ~100-300 KB |
| Compat langages | 100% | Problématique (Java, certaines FFI) |

**Si on utilise Alpine (musl), on mesure un runtime musl. Si on utilise Debian (glibc), on mesure un runtime glibc. Les deux sont valides mais non comparables entre eux. Les résultats musl ne sont PAS représentatifs d'un serveur de production typique (glibc).**

## Choix de l'image de base

| Image | Size | libc | Verdict |
|-------|------|------|---------|
| **`debian:bookworm-slim`** | ~80 MB | glibc | **Recommandé** — stable, représentatif des serveurs prod |
| `ubuntu:24.04` | ~78 MB | glibc | Bonne option, packages récents |
| `fedora:40` | ~170 MB | glibc | OK mais plus lourd |
| `alpine:3.20` | ~7 MB | **musl** | **À éviter** — fausse les mesures RAM |
| `archlinux:base` | ~400 MB | glibc | Trop gros, rolling release instable |
| `distroless` | ~20 MB | glibc | **Incompatible** — pas de shell |

**Décision : `debian:bookworm-slim`** comme image de base unique.

## Avantages de la containerisation

### Reproductibilité
Versions exactes de chaque toolchain figées dans le Dockerfile. Tout le monde obtient les mêmes résultats.

### Multi-version testing
Possibilité de comparer Python 3.11 vs 3.12 vs 3.13, GCC 12 vs 13 vs 14, etc.

### Isolation du host
Plus besoin d'installer 15 toolchains sur la machine. Un `docker build` et tout est prêt.

### CI/CD
Le benchmark peut tourner en CI (GitHub Actions) avec des résultats reproductibles.

## Inconvénients et mitigations

| Inconvénient | Impact | Mitigation |
|-------------|--------|------------|
| Image size (~2-5 GB tous compilateurs) | Build initial long | Multi-stage, `--mount=type=cache` pour apt |
| Overlay FS micro-différences | Négligeable | Documenter le delta |
| Startup bench en conteneur | Overhead si mal architecturé | Exécution interne uniquement |
| Kernel partagé influence les résultats | Pas pire que sans conteneur | Documenter `uname -r` |

## Architecture cible

```
Image de base : debian:bookworm-slim (glibc)
Architecture  : UN conteneur avec tous les toolchains
Exécution     : monter le projet en volume, exécuter le bench à l'intérieur
Mesure        : /proc/[pid]/status depuis l'intérieur (identique au natif)
Support       : docker ET podman (détection automatique)
```
