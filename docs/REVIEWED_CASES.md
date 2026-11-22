# Reviewed benchmark cases

This report is generated from `benchmarks/reviewed-cases.json`. It records
the positive and negative boundary decisions used to review the heuristic
rules; it is not an accuracy percentage for every corpus finding.

- Reviewed cases: **19**
- Confirmed findings: **14**
- Reviewed non-findings: **5**

| Case | Repository | Location | Rule | Decision | Reason |
|---|---|---|---|---|---|
| `clock-retry-timer` | `moonbitlang-async` | `src/retry_test.mbt:40` | `HERM-CLOCK` | finding | The retry test measures elapsed wall-clock time. |
| `clock-timer-test` | `moonbitlang-async` | `src/timer_test.mbt:119` | `HERM-CLOCK` | finding | The timer test asserts behavior against the live clock. |
| `random-environment-rng` | `moonbitlang-x` | `fs/whole_file_contract_test.mbt:17` | `HERM-RAND` | finding | The test calls the ambient environment random generator. |
| `random-crypto-bytes` | `moondiff` | `review-web/backend/internal/crypto/crypto_wbtest.mbt:3` | `HERM-RAND` | finding | The test generates an unseeded encryption key with random_bytes. |
| `environment-read` | `moonbitlang-x` | `path/internal/ffi/is_windows_test.mbt:17` | `HERM-ENV` | finding | The test reads all ambient process environment variables. |
| `environment-write` | `moonbitlang-async` | `src/process/env_test.mbt:68` | `HERM-ENV` | finding | The test mutates ambient process environment state. |
| `network-tcp-server` | `moonbitlang-async` | `src/http/proxy_test.mbt:19` | `HERM-NET` | finding | The proxy test binds a real TCP server. |
| `network-http-client` | `moonbitlang-async` | `src/http/proxy_test.mbt:36` | `HERM-NET` | finding | The proxy test creates a live HTTP client. |
| `process-child` | `moonbitlang-async` | `src/fs/lock_test.mbt:39` | `HERM-PROC` | finding | The lock test starts a child process. |
| `process-shell` | `moonbitlang-async` | `src/shell/run_test.mbt:22` | `HERM-PROC` | finding | The shell test executes an external command. |
| `filesystem-directory` | `moonbitlang-async` | `src/fs/dir_test.mbt:17` | `HERM-FS` | finding | The test opens a filesystem directory. |
| `filesystem-file` | `moonbitlang-async` | `src/fs/dir_test.mbt:28` | `HERM-FS` | finding | The test opens an external file. |
| `sleep-wait` | `moonbitlang-async` | `src/wait_test.mbt:20` | `HERM-SLEEP` | finding | The timing test depends on a sleep interval. |
| `sleep-mutex` | `moonbitlang-async` | `src/mutex_test.mbt:24` | `HERM-SLEEP` | finding | The mutex test uses elapsed time to coordinate contention. |
| `negative-prefetch` | `moondiff` | `review-web/frontend/internal/github_client/snapshot_wbtest.mbt:600` | `HERM-NET` | no-finding | stop_prefetch is not a network fetch operation. |
| `negative-address-parse` | `moonbitlang-async` | `src/raw_fd/raw_fd_test.mbt:176` | `HERM-NET` | no-finding | Parsing an address string performs no network I/O. |
| `negative-process-probe` | `moonbitlang-async` | `src/websocket/unimplemented_test.mbt:21` | `HERM-PROC` | no-finding | The unimplemented probe does not start a process. |
| `negative-filesystem-probe` | `moonbitlang-async` | `src/stdio/unimplemented_test.mbt:19` | `HERM-FS` | no-finding | The unimplemented file API probe does not access the filesystem. |
| `negative-async-spawn` | `moonbitlang-async` | `src/cancellation_test.mbt:19` | `HERM-PROC` | no-finding | Async task spawn is structured concurrency, not a child process. |

A `no-finding` case is an intentionally reviewed boundary where a textual
API-like name does not imply an ambient effect. These cases are regression
tests for false-positive control.
