#!/usr/bin/env python3
"""Converts the Flutter app's ARB translations into HarmonyOS string resources.

    python3 tools/arb_to_harmony.py <path to bweatherflutter/lib/l10n> entry/src/main/resources

* Placeholders ("{city}") become positional arguments ("%1$s"), in the order the
  English ARB declares them. The app always passes them as strings.
* ICU plurals ("{count, plural, =0{..} =1{..} other{..}}") become three plain
  strings, <key>_zero, <key>_one and <key>_other; Strings.count() picks one.
* HarmonyOS-only strings (permission reasons, ability labels) live in EXTRA below.
"""
import json
import re
import sys
from pathlib import Path

LANGUAGES = {"en": "base", "es": "es", "fr": "fr", "ha": "ha", "ig": "ig", "ja": "ja", "yo": "yo", "zh": "zh"}

EXTRA = {
    "module_desc": {"en": "BWeather forecasts"},
    "EntryAbility_desc": {"en": "Weather forecasts for your location and saved places"},
    "EntryAbility_label": {"en": "BWeather"},
    # Home-screen card (phase 4).
    "card_name": {"en": "BWeather"},
    "card_description": {
        "en": "Current weather for your location",
        "fr": "La météo actuelle là où vous êtes",
        "es": "El tiempo actual donde estás",
        "zh": "您所在位置的当前天气",
        "ja": "現在地の今の天気",
        "ha": "Yanayin yanzu a inda kuke",
        "yo": "Ojú ọjọ́ lọ́wọ́lọ́wọ́ níbi tí o wà",
        "ig": "Ihu igwe ugbu a ebe ị nọ",
    },
    "card_open_app": {
        "en": "Open BWeather to set up",
        "fr": "Ouvrez BWeather pour commencer",
        "es": "Abre BWeather para empezar",
        "zh": "打开 BWeather 进行设置",
        "ja": "BWeather を開いて設定してください",
        "ha": "Buɗe BWeather don saitawa",
        "yo": "Ṣí BWeather láti ṣètò",
        "ig": "Mepee BWeather ka ịhazi ya",
    },
    # Background checks on HarmonyOS run every few hours, not hourly as on Android.
    "notifyBackgroundNoteHarmony": {
        "en": "Alerts are checked every few hours, when the system allows, so they can arrive a little late.",
        "fr": "Les alertes sont vérifiées toutes les quelques heures, quand le système le permet : elles peuvent arriver un peu en retard.",
        "es": "Las alertas se comprueban cada pocas horas, cuando el sistema lo permite, así que pueden llegar con algo de retraso.",
        "zh": "系统允许时，每隔几小时检查一次提醒，因此可能会稍有延迟。",
        "ja": "通知はシステムが許可するときに数時間ごとに確認されるため、少し遅れて届くことがあります。",
        "ha": "Ana duba faɗakarwa bayan 'yan sa'o'i idan tsarin ya ba da dama, don haka za su iya zuwa a makare kaɗan.",
        "yo": "A máa ń ṣàyẹ̀wò ìkìlọ̀ lẹ́yìn wákàtí díẹ̀ nígbà tí ẹ̀rọ bá gbà, nítorí náà wọ́n lè dé pẹ́ díẹ̀.",
        "ig": "A na-enyocha ọkwa ka awa ole na ole gachara mgbe usoro kwere, ya mere ha nwere ike ịbịa obere oge.",
    },
    "permission_location_reason": {
        "en": "Used to show the forecast for where you are.",
        "es": "Se usa para mostrar el pronóstico de donde estás.",
        "fr": "Sert à afficher les prévisions de l'endroit où vous êtes.",
        "ja": "現在地の天気予報を表示するために使用します。",
        "zh": "用于显示您所在位置的天气预报。",
    },
}


def plural_forms(message):
    """{count, plural, =0{a} =1{b} other{c}} -> {"zero": a, "one": b, "other": c}"""
    body = message[message.index("plural,") + len("plural,"):message.rindex("}")]
    forms, i = {}, 0
    while i < len(body):
        match = re.compile(r"\s*(=\d+|zero|one|two|few|many|other)\s*\{").match(body, i)
        if not match:
            break
        selector, depth, j = match.group(1), 1, match.end()
        while depth:
            depth += {"{": 1, "}": -1}.get(body[j], 0)
            j += 1
        forms[{"=0": "zero", "=1": "one"}.get(selector, selector)] = body[match.end():j - 1]
        i = j
    return forms


def to_format(text, names):
    """Swaps {name} for %N$s, escaping literal percent signs when there are arguments."""
    if not names:
        return text
    text = text.replace("%", "%%")
    for index, name in enumerate(names, start=1):
        text = text.replace("{" + name + "}", f"%{index}$s")
    return text


def main(arb_dir, resources):
    english = json.loads((Path(arb_dir) / "app_en.arb").read_text(encoding="utf-8"))
    order = {key: list((english.get("@" + key) or {}).get("placeholders", {}).keys())
             for key in english if not key.startswith("@")}

    for lang, folder in LANGUAGES.items():
        arb = json.loads((Path(arb_dir) / f"app_{lang}.arb").read_text(encoding="utf-8"))
        strings = []
        for key, names in order.items():
            message = arb.get(key, english[key])
            if "plural," in message:
                forms = plural_forms(message)
                for form in ("zero", "one", "other"):
                    text = forms.get(form, forms["other"]).replace("{count}", "%1$s").replace("%", "%%").replace("%%1$s", "%1$s")
                    strings.append({"name": f"{key}_{form}", "value": text})
            else:
                strings.append({"name": key, "value": to_format(message, names)})
        for key, values in EXTRA.items():
            if lang in values:
                strings.append({"name": key, "value": values[lang]})
        out = Path(resources) / folder / "element" / "string.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"string": strings}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"{folder}: {len(strings)} strings")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
