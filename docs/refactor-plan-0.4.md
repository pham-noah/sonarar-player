# Refactor plan for 0.4 — the five deferred items

Written at the end of the 0.3.3 session, where the download-engine work consumed the
available budget. The base is `main` @ `237768c` (0.3.3, released): analyzer clean,
1,884 tests green. Start each item on its own branch from `main`, and do not merge one
into another.

Order matters: each item removes state the next one has to work around.

---

## 0. Ground rules (they earned their place this session)

- **Verification is the log, not the pipeline.** Redirect to a file, append
  `FLUTTER_EXIT=$?`, read that. A suite piped through `tail` reports tail's status — that
  produced a false green this session.
- **One commit per item**, message states the guarantee that changed, not the diff.
- **`flutter analyze` must be 0 issues**, not "no errors".
- **Grep before you trust a listing.** Two bugs this session came from reading a
  truncated `head`/`tail` and believing it: a dependency that "had no x86_64" (it did),
  and an APK that looked built and was 4.7x too large.
- **Anything that ships gets its ABI list checked**, not just its size:
  `aapt2 dump badging app-release.apk | grep native-code`.

---

## 1. `PlayQueue` — collapse `_source` + `_order`

**Why first.** Every queue edit is index surgery across two lists kept in sync by hand.
`replaceCurrent` is ~35 lines of it, and the queue-gap fix had to reason about both.

**Scope.** `lib/player/queue.dart`. One authoritative list; `_order` becomes a derived
view (or disappears). Any invariant currently enforced by remembering to update both
should become unrepresentable.

**Risk.** `replaceCurrent`, `insertNext`, and the shuffle/repeat ordering interaction.
`PlayQueue._bumpOrder()` feeds `engineIsStale`, so ordering bugs surface as
reloads rather than as wrong songs — check the log line `[Sonarar][LOAD]`.

**Tests first.** Extend `test/player/queue_edit_test.dart`: replay the full edit
vocabulary (add, remove, move, play-next, replace-current, shuffle on/off, repeat
one/all) against the single list and assert the engine-facing order each time.

**Green means:** those tests plus the queue-gap regression in `track_loader_test.dart`.

---

## 2. `AppPrefs` — a key registry

**Why second.** Adding one field (`paletteIndex`) meant editing five places: field,
`copyWith`, encode, decode, and the UI. That is the audit's open/closed finding,
measured rather than asserted.

**Scope.** `lib/core/prefs.dart`. A table of keys (name, type, default, encoder,
decoder) drives `fromJson`/`toJson`/`copyWith`, so a new preference is one row.

**Risk.** Silent default drift — a key whose decoder tolerates junk is a feature
(`palette: 'purple'` must not break launch), but a key that silently reads as the wrong
default is not.

**Tests first.** The round-trip tests already exist and are the net:
`test/theme/palette_pref_test.dart` (round trip, missing key, junk value, `copyWith`)
and `test/first_run_test.dart`. Add one test per new key shape before the registry
lands, so the registry is judged by them.

**Green means:** every preference still round-trips, and an old file with missing keys
reads as defaults.

---

## 3. `AudioEngine` — five booleans become one state

**Why third.** `_wantPlay`, `_playOutstanding`, `_playRetries`,
`_suppressNextCompletion`, `_skipRequested` are one state machine pretending to be five
flags. Combinations that cannot happen are currently representable, and some of them
probably do.

**Scope.** `lib/player/audio_engine.dart`. An explicit state enum plus the existing
`FadeEnvelope` and `PlaybackTicker`. Keep `PlaybackEngine`'s interface untouched —
`PlayerController` and `TrackLoader` depend on it and should not notice.

**Risk.** Completion accounting is where the booleans encode real history
(`_suppressNextCompletion` exists because just_audio fires completion after a skip).
Write down each flag's reason before removing it; a flag whose reason you cannot state
is the one that will regress.

**Tests first.** `test/player/fake_engine.dart` + `player_controller_test.dart` cover
transport; add state-machine tests for: play during init, skip during play,
completion-after-skip, fade then stop, retry after a load failure.

---

## 4. `AppState` clusters — bonds, context, queue

**Why fourth.** `TagLayer` established the pattern: extract the object, delegate
getters, leave read sites alone. 1,749 lines and 79 `notifyListeners()` remain.

**Scope.** `lib/core/app_state.dart`. One domain per commit — bonds first (it was
measured as a field plus two forwards, so it may collapse rather than extract), then
context, then queue. The queue cluster is large and should get its own notifier so a
queue change stops rebuilding the shell.

**Risk.** Notification granularity: a per-domain notifier that stops notifying is a
silently dead UI. After each cluster, grep every `notifyListeners()` call site and
confirm the owning notifier is the one being pinged.

**Tests first.** There are `AppState` tests already; add one per cluster that asserts a
mutation notifies the *right* notifier — the class of bug fixed earlier when
`setPlaces`/`setContextRules` forgot to notify.

---

## 5. `main._load()` — a bootstrapper

**Why last.** It is 304 lines of sequential procedure, parallelised but not extracted.
Lowest risk, lowest payoff — but it is the file every other change has to edit, so it
is worth doing once the domain code is settled.

**Scope.** Extract `Bootstrapper` behind the existing boot-phase log
(`[Sonarar] boot NN% …`), so the log proves behaviour is identical. Each phase becomes
a named step with its own timing, and the test suite gets a way to run phases in
isolation.

**Risk.** Ordering: the parallel platform reads have a dependency order that is not
obvious (prefs before layout, layout before the first frame). The phase log is the
oracle.

**Note from the 0.3.3 session.** Boot timings measured on an x86_64 emulator:
cold `reading your library=4356ms`, warm `1321ms`, total 4.9 s / 3.3 s. That is mostly
MediaStore warm-up, not per-launch cost — profile on a phone before optimising it.

---

## Also outstanding (not refactors)

1. **On-device update check:** install 0.3.2 on the phone, confirm it offers 0.3.3 and
   downloads the arm64 asset, and that the sheet shows notes/size/progress.
2. **Play a downloaded track** through the player — the engine test wrote a 6 MB webm
   to disk; it has not been played back.
3. **F-Droid recipe** still needs the 0.3.3 version and a note that the engine is
   fetched at runtime (metadata may require a network-usage note).

---

## Release checklist (learned the hard way)

1. `flutter analyze` → 0 issues.
2. `flutter test` → log to a file, read `FLUTTER_EXIT`.
3. `flutter build apk --release --target-platform android-arm64 --dart-define=SONARAR_DOWNLOADS=false`
4. `aapt2 dump badging` → `versionCode`, `versionName`, and **`native-code: 'arm64-v8a'` only**.
5. `apksigner verify --print-certs` → `e6e2f7d7…` (the key that upgrades installed builds).
6. `sha256sum` → paste into the release body (the app verifies and deletes a mismatch).
7. Copy to `Sonarar-release/`, `git tag -a vX.Y.Z`, push branch **and** tag, `gh release create`.
8. Verify the asset uploaded: `gh release view vX.Y.Z --json assets`.
