# 📋 Flutter Forms Engine — Google Forms Clone

A **production-ready**, fully responsive Google Forms clone built with Flutter Web, Material 3, and Telegram Mini App (TMA) integration.

---

## ✨ Features

| Feature | Details |
|---|---|
| **Dynamic Form Builder** | 9 field types: short text, long text, radio, checkbox, dropdown, date picker, time picker, star rating, section headings & dividers |
| **Real-time Validation** | Required, minLength, maxLength, email, URL, number rules with inline error messages |
| **Progress Bar** | Live completion % computed from answered fields |
| **Responsive Layout** | Desktop (centred card, max-width 680px), Mobile (full-width), Telegram (safe-area aware, pull handle) |
| **Telegram Theme Sync** | Reads `themeParams` → maps to Flutter `ColorScheme`; auto-detects dark/light |
| **TMA expand()** | Called on init via `web/index.html` before Flutter boots (zero flash) |
| **Animated** | Staggered field entrance animations via `flutter_animate` |
| **State Management** | Provider (`ChangeNotifier`) — easy to swap for Riverpod |
| **JSON-driven** | Entire form structure is a JSON document — load from API or static asset |

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry, Provider wiring, theme setup
├── data/
│   └── sample_form.dart         # Sample JSON form schema (all field types)
├── models/
│   └── form_field_model.dart    # FormSchema, FormFieldModel, FieldOption, FieldValidation
├── providers/
│   └── form_provider.dart       # FormState (ChangeNotifier) — answers, validation, submit
├── services/
│   └── telegram_service.dart    # TMA bridge: themeParams, expand(), sendData(), mainButton
├── utils/
│   └── telegram_theme.dart      # TelegramThemeParams → Flutter ThemeData converter
└── widgets/
    ├── form_generator.dart      # ⭐ Core FormGenerator engine
    ├── field_widgets.dart       # Individual field renderers (one class per type)
    └── responsive_wrapper.dart  # ResponsiveFormWrapper (desktop/mobile/telegram shells)
web/
└── index.html                   # Telegram SDK script tag + expand() before Flutter boots
pubspec.yaml
```

---

## 🚀 Setup & Run

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Run in browser
```bash
flutter run -d chrome
```

### 3. Build for production (web)
```bash
flutter build web --release
```

Then serve the `build/web/` folder on your hosting (Cloudflare Pages, Firebase Hosting, Vercel, etc.).

---

## 🤖 Telegram Mini App Integration

### Enabling real TMA calls

The `TelegramService` is a stub-ready wrapper. To activate real Telegram SDK calls:

1. Open `lib/services/telegram_service.dart`
2. Uncomment the `import 'package:telegram_web_app/telegram_web_app.dart';` line
3. Replace `_tryGetTelegramParams()` with the real block shown in the file comments

```dart
// Replace the stub _tryGetTelegramParams() body with:
final twa = TelegramWebApp.instance;
if (!twa.isAvailable) return null;
return {
  'bg_color':               twa.themeParams.bgColor,
  'secondary_bg_color':     twa.themeParams.secondaryBgColor,
  'text_color':             twa.themeParams.textColor,
  'hint_color':             twa.themeParams.hintColor,
  'link_color':             twa.themeParams.linkColor,
  'button_color':           twa.themeParams.buttonColor,
  'button_text_color':      twa.themeParams.buttonTextColor,
  'accent_text_color':      twa.themeParams.accentTextColor,
  'destructive_text_color': twa.themeParams.destructiveTextColor,
  'header_bg_color':        twa.themeParams.headerBgColor,
  'section_bg_color':       twa.themeParams.sectionBgColor,
  'section_separator_color':twa.themeParams.sectionSeparatorColor,
};
```

### Bot webhook

After submission, send the JSON payload to your bot:
```dart
// In form_provider.dart submit():
TelegramService.instance.sendData(jsonEncode(response.toJson()));
```

---

## 📄 Sample Form JSON Schema

```json
{
  "id": "form_001",
  "title": "My Form",
  "description": "A description shown under the title.",
  "accentColor": "#6366F1",
  "showProgressBar": true,
  "confirmationMessage": "Thank you!",
  "fields": [
    {
      "id": "name",
      "type": "shortText",
      "label": "Full Name",
      "placeholder": "Jane Doe",
      "isRequired": true,
      "options": [],
      "validations": [
        { "rule": "required", "errorMessage": "Name is required." }
      ]
    },
    {
      "id": "choice",
      "type": "radio",
      "label": "Preferred option",
      "isRequired": true,
      "options": [
        { "id": "a", "label": "Option A" },
        { "id": "b", "label": "Option B" }
      ],
      "validations": [
        { "rule": "required", "errorMessage": "Please choose one." }
      ]
    }
  ]
}
```

### Supported `type` values

| type | Widget |
|---|---|
| `shortText` | Single-line `TextFormField` |
| `longText` | Multi-line `TextFormField` with char counter |
| `radio` | Animated radio tiles |
| `checkbox` | Animated checkbox tiles (multi-select) |
| `dropdown` | `DropdownButtonFormField` |
| `datePicker` | `showDatePicker` dialog |
| `timePicker` | `showTimePicker` dialog |
| `rating` | Interactive star rating (1–5 or custom `maxRating`) |
| `heading` | Section title label (non-interactive) |
| `divider` | Visual separator line |

### Supported `validations[].rule` values

| rule | Notes |
|---|---|
| `required` | Fails if empty/null |
| `minLength` | `value` = minimum character count |
| `maxLength` | `value` = maximum character count |
| `email` | Regex email format check |
| `url` | Regex URL format check |
| `number` | Fails if not parseable as double |

---

## 🎨 Theming

The `TelegramThemeParams` class maps any Telegram `themeParams` map to a full Flutter `ThemeData`. To override the accent colour per form, set `accentColor` in the form JSON:

```json
{ "accentColor": "#EC4899" }
```

To test dark mode outside Telegram:
```dart
// In lib/main.dart, temporarily:
themeMode: ThemeMode.dark,
```

---

## 🔄 Loading Forms Dynamically

Replace the static `sampleFormJson` with an API call:

```dart
// In main() or a FutureProvider:
final response = await http.get(Uri.parse('https://api.yourserver.com/forms/123'));
final schema = FormSchema.fromJson(jsonDecode(response.body));
formState.loadSchema(schema);
```

---

## 📦 Key Dependencies

| Package | Purpose |
|---|---|
| `provider` | State management |
| `telegram_web_app` | Telegram Mini App SDK wrapper |
| `google_fonts` | Plus Jakarta Sans typeface |
| `flutter_animate` | Entrance animations |
| `intl` | Date formatting |
| `gap` | Spacing utility |
| `uuid` | Unique ID generation |
