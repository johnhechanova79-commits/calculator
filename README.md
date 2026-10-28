# NeoCalc

NeoCalc is a Flutter calculator for Android with live expression previews, a unit converter, and locally saved calculation history.

## Run

Install Flutter and an Android SDK, then run:

```sh
flutter pub get
flutter run
```

Build a debug APK with `flutter build apk --debug`.

## Features

- Arithmetic with operator precedence, decimals, sign toggle, backspace, and divide-by-zero handling.
- Temperature, volume, currency, and area conversion.
- Currency conversion uses fixed offline rates: 1 USD = 0.92 EUR, 0.79 GBP, 150 JPY, or 56 PHP.
- History is stored on-device, newest first, with a 100-entry limit.

Run the test suite with `flutter test`.