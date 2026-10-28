# NeoCalc — Design Specification

Android calculator with a unit converter and calculation history, based on the supplied GUI mockup (three portrait screens, dark glass / neumorphic style with a gold accent).

- **Platform:** Android 8.0+ (minSdk 26), portrait
- **Stack:** Kotlin, Jetpack Compose, Material 3, single Activity, ViewModel + StateFlow
- **Persistence:** SharedPreferences (history stored as JSON)

---

## 1. Screens

### 1.1 Calculator (Screen 1)

```
┌─────────────────────────┐
│                      ≡  │  ← top-right menu icon (Converter / History)
│ ┌─────────────────────┐ │
│ │ 450 + 500 + 1000    │ │  ← expression, small, right-aligned, white
│ │                  =  │ │
│ │              1950   │ │  ← result, large, gold
│ │          history →  │ │  ← tiny hint link
│ └─────────────────────┘ │
│                         │
│  [ C ] [+/-] [ ⌫ ] [ ÷ ]│
│  [ 7 ] [ 8 ] [ 9 ] [ × ]│
│  [ 4 ] [ 5 ] [ 6 ] [ − ]│
│  [ 1 ] [ 2 ] [ 3 ] [ + ]│
│  [   0      ] [ . ] [ = ]│
└─────────────────────────┘
```

- Glass display card (rounded 16dp) with a faint gold gradient border on the top-left edge.
- Expression line updates live; result line shows the live preview, and becomes final on `=`.
- Keypad is a 5-row × 4-column grid. `0` spans two columns.
- Operators (`÷ × − +`) are label-colored gold-grey; `=` is the highlighted key with a gold glow.
- Tapping **history →** opens the History screen; the ≡ icon opens the screen menu.

### 1.2 Unit Converter (Screen 2)

```
┌─────────────────────────┐
│ ←     Unit Converter  ≡ │
│ [Temperature][Volume][Currency][Area]  ← tab row, selected = gold text
│ ┌───────────┐ ┌───────┐ │
│ │        29 │ │Celsius▾│ │  ← input field + unit dropdown
│ └───────────┘ └───────┘ │
│ ┌───────────┐ ┌───────┐ │
│ │      84.2 │ │Fahrenh▾│ │  ← converted value + unit dropdown
│ └───────────┘ └───────┘ │
│  [ C ] [+/-] [ ⌫ ] [ ÷ ]│  ← same keypad (operators disabled / dimmed)
│  [ 7 ] [ 8 ] [ 9 ] [ × ]│
│   ...                   │
└─────────────────────────┘
```

- Four categories as in the mockup: **Temperature, Volume, Currency ("Kurs"), Area**.
- Top field is the editable input (focused by the keypad); the bottom field is read-only output.
- Each field has a dropdown to choose its unit.
- Converting is live; tapping `=` saves the conversion into History (e.g. "29 Celsius = 84.2 Fahrenheit").
- Currency uses fixed offline rates (documented in code); it can be swapped for a live API later.

### 1.3 History (Screen 3)

```
┌─────────────────────────┐
│ ←        History     ≡  │
│ ↓                       │  ← sort / scroll hint
│        450 + 500 + 1000 │
│                      =  │
│                   1950  │  ← gold
│ ─────────────────────── │
│          29 Celsius     │
│                      =  │
│        84.2 Fahrenheit  │
│ ─────────────────────── │
│               45 × 10   │
│                      =  │
│                    450  │
│ ↑                    🗑 │  ← bottom-left: scroll up, bottom-right: clear all
└─────────────────────────┘
```

- Newest entry first, right-aligned, thin divider between entries.
- Tapping an entry loads its result back into the Calculator.
- Trash icon clears all history (with confirmation dialog).

---

## 2. Visual Language

### 2.1 Colors

| Token            | Hex        | Use                                   |
|------------------|------------|---------------------------------------|
| `Background`     | `#3A3F4B`  | Outer app background (behind phone)   |
| `Surface`        | `#1B1F2B`  | Screen background                     |
| `SurfaceVariant` | `#262B3A`  | Display card, input fields            |
| `KeyFace`        | `#2E3445`  | Default key                           |
| `KeyFaceTop`     | `#3A4155`  | Key gradient top                      |
| `KeyBorder`      | `#4A5268`  | 1dp key outline (top-left highlight)  |
| `Gold`           | `#E8A33D`  | Results, selected tab, `=` key        |
| `GoldSoft`       | `#8A6A35`  | Glow / gradient tint on keys          |
| `OnSurface`      | `#E6E8EE`  | Primary text (digits, expression)     |
| `OnSurfaceDim`   | `#8E95A8`  | Secondary text, hints, dividers       |

### 2.2 Typography

| Role            | Size  | Weight  | Color       |
|-----------------|-------|---------|-------------|
| Result          | 44 sp | Light   | Gold        |
| Result (history)| 28 sp | Normal  | Gold        |
| Expression      | 16 sp | Normal  | OnSurface   |
| Key label       | 22 sp | Medium  | OnSurface   |
| Tab / title     | 14 sp | Medium  | OnSurface   |
| Hint            | 10 sp | Normal  | OnSurfaceDim|

Font: system default sans (Roboto). Tabular figures are used for numbers.

### 2.3 Shape & Elevation

- Screen corner radius: 24dp
- Display card / fields: 16dp
- Keys: 12dp, 1dp border, vertical gradient `KeyFaceTop → KeyFace`, with a soft gold radial tint in the bottom-right of each key (the "glass" look from the mockup)
- Pressed state: scale 0.96, gold border at 60% alpha
- Spacing: 12dp grid gap, 16dp screen padding

---

## 3. Components

| Component        | Description                                                      |
|------------------|------------------------------------------------------------------|
| `CalcKey`        | Rounded glass key. Variants: Digit, Operator, Action (C, ±, ⌫), Equals |
| `KeyPad`         | 4-column grid, `0` double width, reused by Calculator and Converter |
| `DisplayCard`    | Expression + result + history hint                              |
| `TopBar`         | Back arrow (optional), centered title, menu icon                |
| `CategoryTabs`   | Segmented tab row, selected label in gold                       |
| `UnitField`      | Value box + unit dropdown                                       |
| `HistoryRow`     | Right-aligned expression / `=` / result, divider                |

---

## 4. Navigation

```
Calculator ──(≡ menu)───────► Unit Converter / History
Calculator ──("history →")──► History
Unit Converter ──(←)────────► Calculator
Unit Converter ──(≡ menu)───► Calculator / History
History ──(←)───────────────► Calculator
History ──(tap an entry)────► Calculator (result loaded)
```

The ≡ icon opens a dropdown with three items: **Calculator, Unit Converter, History**. The back stack is always `[calculator]` or `[calculator, other]`.

Implemented with Navigation Compose, routes: `calculator`, `converter`, `history`.

---

## 5. Behavior

### Calculator
- Supports `+ − × ÷`, decimals, `+/-` (negates the current number), backspace, clear.
- Operator precedence is respected (`×`/`÷` before `+`/`−`).
- Division by zero shows `Error`.
- Results are formatted without trailing zeros (`1950`, not `1950.0`), up to 10 significant decimals.

### Converter
- Temperature: Celsius, Fahrenheit, Kelvin
- Volume: Liter, Milliliter, Gallon (US), Cup (US)
- Currency: USD, EUR, GBP, JPY, PHP (offline fixed rates)
- Area: m², km², ft², acre, hectare
- Conversion goes through a base unit (or direct formulas for temperature).

### History
- Max 100 entries, newest first.
- Stored as JSON in SharedPreferences, survives restarts.

---

## 6. Data Model

```kotlin
data class HistoryEntry(
    val id: Long,
    val expression: String,   // "450 + 500 + 1000"  or "29 Celsius"
    val result: String,       // "1950"              or "84.2 Fahrenheit"
    val timestamp: Long
)
```

---

## 7. Project Structure

```
app/src/main/java/com/neocalc/app/
├── MainActivity.kt
├── ui/
│   ├── theme/Theme.kt
│   ├── components/Components.kt
│   ├── CalculatorScreen.kt
│   ├── ConverterScreen.kt
│   └── HistoryScreen.kt
├── logic/
│   ├── ExpressionEvaluator.kt
│   └── UnitConverter.kt
└── data/
    ├── HistoryStore.kt
    └── AppViewModel.kt
```

---

## 8. Accessibility

- Minimum touch target 48dp; keys are much larger.
- Gold on `#1B1F2B` contrast ≈ 8:1; dim text meets 4.5:1.
- Every key has a content description (e.g. "divide", "backspace").
- Supports system font scaling; the result text shrinks to fit rather than clipping.
