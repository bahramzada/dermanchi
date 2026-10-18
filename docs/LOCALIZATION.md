# Localization

Dərmanchı ships in **English** (source and fallback language) and **Azerbaijani**. Every user-facing string lives in one place:

```
Dermanchi/Resources/Localizable.xcstrings     ← the String Catalog, shared by the app and the widget extension
Dermanchi/Logic/Localization.swift            ← AppLanguage.supported, the language setting, tr(...)
```

## How the language is chosen

1. **Settings → Language** has three choices: *System default*, *English* and *Azərbaycanca*. The choice is stored in the App Group (`group.com.raullte.dermanchi`), so the widgets, the Live Activity and the notifications read the same value.
2. *System default* picks the first language in the iPhone's preferred-language list that the app supports. If none matches, it falls back to **English**.
3. Dates, times and durations come from Foundation's own formatters, using the chosen language together with the iPhone's region. That is why the 12/24-hour clock follows the region and no per-language date formats are written by hand.

Switching the language rebuilds notifications, reloads the widgets and updates the Live Activity right away. No restart is needed.

## Writing strings in code

| Where | Write | Notes |
| --- | --- | --- |
| SwiftUI views | `Text("Start the day")` | Literals are looked up in the catalog using the language set on the root view. |
| Anything that needs a `String` (notifications, widgets, helpers, ternaries) | `tr("Start the day")` | `Text(cond ? "a" : "b")` is **not** localized: two literals become a plain `String`. Use `tr(...)`. |
| Verbatim text (names, numbers, dates) | `Text(verbatim: "\(a) – \(b)")` | Keeps it out of the catalog. |

Rules of thumb:

- **The key is the English text**, for example `"Next: \(name) (in \(minutes) min)."` becomes the key `Next: %@ (in %lld min).`
- **Write whole sentences.** Do not glue fragments together: word order and suffixes differ between languages. Put the values inside the sentence as arguments.
- **Plurals** use the catalog's *Vary by Plural* (see `Every %lld hours` or the `From %@ until now, %lld drops…` substitution).
- Drug names (Xiloial, Moxi-R, Maxidex) and the app name are brand names. They are not translated.

## Adding a language

Say you want to add Russian (`ru`).

1. **Register it** in `AppLanguage.supported` (`Dermanchi/Logic/Localization.swift`):

   ```swift
   AppLanguage(code: "ru", nativeName: "Русский"),
   ```

   The Settings list picks it up on its own.

2. **Translate it.** Open `Localizable.xcstrings` in Xcode, add *Russian* with the **+** button under the language list, and fill in every row. Plural rows need one entry per plural category of the language (Russian has `one`, `few`, `many`, `other`).

3. **Run the tests.** The suite fails until the work is complete:

   ```bash
   xcodebuild test -project Dermanchi.xcodeproj -scheme Dermanchi \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
   ```

   | Test | What it catches |
   | --- | --- |
   | `testEveryKeyIsTranslatedIntoEverySupportedLanguage` | a missing or empty translation |
   | `testCatalogHasNoLanguageThatIsNotRegistered` | a language in the catalog that is missing from `AppLanguage.supported` |
   | `testPlaceholdersMatchAcrossLanguages` | `%@` / `%lld` that differ between translations |
   | `testBuiltBundleContainsEverySupportedLanguage` | a language that did not make it into the app bundle |
   | `testEveryLiteralKeyInSourcesExistsInCatalog` | a string used in code but missing from the catalog |
   | `testEveryCatalogKeyIsUsedInSources` | a catalog row nobody uses any more |
   | `testNoAzerbaijaniTextIsHardcodedInSources` | text that slipped into code instead of the catalog |
   | `testNoRawHumanTextInTernaryBranches` | `Text(cond ? "a" : "b")` that would never be translated |

4. **Look at it.** Run the app, pick the language in Settings, and check the Today screen, the widgets and the Live Activity. Long translations are the usual surprise on the Lock Screen widget.

To change the *fallback* language, change `AppLanguage.fallback` and the catalog's `sourceLanguage` together. A test checks that they agree.

## Regenerating the README images

Widget images are rendered from the real views:

```bash
TEST_RUNNER_SNAPSHOT_DIR=$PWD/docs/screenshots TEST_RUNNER_SNAPSHOT_LANG=en \
  xcodebuild test -project Dermanchi.xcodeproj -scheme Dermanchi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:DermanchiTests/WidgetSnapshotTests
```

For app screens, launch a debug build in the simulator with demo data in the language you want:

```bash
xcrun simctl launch booted com.raullte.dermanchi -demo -demo-lang az
xcrun simctl launch booted com.raullte.dermanchi -demo -demo-lang en -demo-due   # next drop is overdue
```
