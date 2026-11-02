# Languages

Sonarar speaks English, Tiếng Việt, Suomi, 简体中文 and 日本語. This page is how to add the next one without breaking the five that exist.

## Adding a language

1. **Copy the template.** `app_src/lib/l10n/app_en.arb` → `app_src/lib/l10n/app_xx.arb`, and set `"@@locale": "xx"`. Keep the `@key` metadata blocks; `flutter gen-l10n` reads the `placeholders` from them.
2. **Translate values only.** Never edit a key on one side only, never rename a key, never drop a `{placeholder}`. A placeholder is an argument the Dart code passes; a missing one is a crash at runtime, not a fallback.
3. **Plurals stay ICU.** `{count, plural, =1{…} other{…}}` — and `other` is mandatory. `=1` is an exact-value branch and is legal in every language, so it can stay even where the language has no special singular form.
4. **Register.** Run `flutter test test/l10n` — the gate below checks structure. Nothing checks whether it sounds like the language. That part needs a reader.
5. **Ship it.** The settings picker reads `AppLocalizations.supportedLocales`, so the language appears the moment its ARB exists. There is no list to update.

## Scripts with no upper case and no tracking

`lib/l10n/script.dart` holds the whole decision:

- `capsFor(context, text)` — upper-cases only where the script has case. `toUpperCase()` on Japanese is a silent no-op, so a label that was shouted in English would simply stop shouting.
- `trackingFor(context, px)` — returns `0` for `ja`, `zh`, `ko`, `th`, `lo`, `my`. Wide letter-spacing stretches characters designed to sit on a grid.

A new uppercase or letter-spaced label must use these two. The one exception is the `TextTheme` in `theme/skin.dart`, where no `BuildContext` exists yet; the comment there says so.

## What the gate checks

`test/l10n/arb_gate_test.dart`, on every `flutter test`:

- a locale missing a key the template has
- a locale inventing a key the template does not have
- a placeholder set that changed in either direction
- a plural that lost its `other` branch
- a `{placeholder}` in the template that is not declared in `@key`
- any key nothing in `lib/` references

`test/l10n/script_test.dart` checks the caps and tracking policy. `test/screens/layout_fits_test.dart` pumps the densest page in every spoken language and fails on a layout exception — English goldens cannot see a Finnish compound.

## Why the gate exists

A missing key falls back to English silently. Without the gate, a locale can be 90% translated and look finished, and no test or golden would say otherwise.
