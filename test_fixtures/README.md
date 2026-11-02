# Private statement fixtures

Put a real BPI Statement of Account PDF here as `bpi_soa_sample.pdf`.

This folder is git-ignored except for this README. Never commit bank
statements, extracted text, or account numbers.

The committed parser tests use anonymised layout fixtures under
`test/helpers/`. An optional local test loads this PDF when present:

```
flutter test test/unit/bpi_sample_pdf_test.dart
```
