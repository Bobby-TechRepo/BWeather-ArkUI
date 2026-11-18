# BWeather for HarmonyOS

An ArkUI (ArkTS, state management V2) port of the BWeather Flutter app. It uses
the same Open-Meteo data, look, and behaviour on phones, tablets and 2-in-1 devices.

Target: HarmonyOS 6.1.1 (API 24), built with DevEco Studio.

## Status

The port is delivered in phases. After each phase, build and test it.

| Phase | Contents | State |
| --- | --- | --- |
| 1 | Forecast, Locations, Settings, welcome screen, city search, About/legal, 8 languages | Done |
| 2 | Trip planner (multi-stop, typical weather beyond 16 days, packing list, share) | Done |
| 3 | Background alerts (morning briefing, rain, severe weather) and the trip reminder | To do |
| 4 | Home-screen card (service widget) | To do |
| 5 | Rain radar | To do |

## Layout

```
entry/src/main/ets/
  common/      Units and conversion, wall-clock times, formatting, theme colours, storage, strings
  model/       Forecast data (plain interfaces) and pure logic: tips, rain outlook, climate normals
  data/        Open-Meteo / Nominatim / ipapi clients, location service, built-in capitals
  state/       Stores (@ObservedV2): settings, weather (places + forecasts), search, UI
  components/  Forecast view and cards, sky background, places list, settings rows
  pages/       Index (root + navigation), main screen, tabs, city search, about/legal
entry/src/test/  Local unit tests (Hypium): conversion, times, forecast helpers, normals, astronomy
tools/           Scripts that generate resources from the Flutter project
```

## How it maps to the Flutter app

- **Cubits become stores.** Each store is an `@ObservedV2` class with one `@Trace state` field. Every change replaces that field, as `emit` did in the Flutter app.
- **Saved data.** State is saved as JSON files in the app's files directory (what HydratedBloc did in the Flutter app).
- **Times.** Times at a place are stored as "wall time": the local clock reading encoded as UTC milliseconds. Format them with `timeZone: 'UTC'`; see `common/WallTime.ets`. This matches the zone-less DateTimes the Flutter app used.
- **Units.** Forecasts are always fetched in metric and converted on the device. Changing units is instant and works offline.

## Regenerating resources

The commands assume the Flutter project sits next to this one. Run them from the project root:

```
python3 tools/arb_to_harmony.py ../bweatherflutter/lib/l10n entry/src/main/resources   # strings, 8 languages
python3 tools/icons.py ../bweatherflutter/files entry/src/main/resources/base/media     # weather icons (PNG)
python3 tools/ui_icons.py entry/src/main/resources/base/media                          # UI icons (SVG)
python3 tools/app_icon.py ../bweatherflutter/files                                     # app and start icons
```

- **Strings.** ARB plurals become `<key>_zero`, `<key>_one` and `<key>_other`; `S.count()` picks the right one.
- **Placeholders.** These become `%1$s`, `%2$s`, and so on, and are always filled with strings.
- **Tools.** `icons.py` and `app_icon.py` need `rsvg-convert`, and `app_icon.py` also needs Pillow.

## Differences from the Flutter app

- **Fonts.** The app uses the system font (HarmonyOS Sans) instead of Inter and Outfit.
- **Language.** Changing the language restarts the app, so every screen picks it up.
- **Crash reporting.** There is no Sentry on HarmonyOS, so the setting is left out.
- **Animations.** The Lottie animations are replaced by weather icons.
