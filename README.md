# Joint Expenses

A Flutter (Android + iOS) app for two people who share one household budget.
Both partners record income and expenses; totals, balance and category
breakdowns update live on both phones through Supabase Realtime.

- **Frontend:** Flutter 3.47 / Dart 3.13, Material 3, Riverpod, GoRouter, fl_chart
- **Backend:** Supabase – Auth, Postgres, Realtime, Row Level Security, RPC functions
- **Money:** stored as `numeric(14,2)` in Postgres, handled as integer minor units
  (`Money`) in Dart – no floating point anywhere in the financial path.

---

## 1. Prerequisites

| Tool | Version |
| --- | --- |
| Flutter SDK | 3.47.x stable (Dart 3.13) |
| Android Studio + Android SDK (API 35) / Xcode 16 | for building & running |
| Supabase project | free tier is fine |
| Supabase CLI (optional) | for `supabase db push` |

```bash
flutter doctor        # everything you intend to build for should be green
flutter pub get
```

## 2. Create the Supabase backend

1. Create a project at <https://supabase.com/dashboard>.
2. Apply the migrations in `supabase/migrations/` **in file-name order**:

   | File | Contents |
   | --- | --- |
   | `20260101000000_initial_schema.sql` | enums, tables, constraints, indexes, triggers (auto profile creation, category/type validation, owner protection) |
   | `20260101000001_rls_policies.sql` | RLS on every table + `SECURITY DEFINER` membership helpers |
   | `20260101000002_functions.sql` | RPCs: `create_household`, `create_household_invite`, `join_household_with_invite`, `reassign_and_delete_category`, default category seeding |
   | `20260101000003_realtime.sql` | `REPLICA IDENTITY FULL` + adds tables to the `supabase_realtime` publication |

   Either paste each file into **SQL Editor → New query → Run**, or with the CLI:

   ```bash
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```

3. **Authentication → URL Configuration → Redirect URLs** – add:

   ```
   jointexpenses://login-callback
   jointexpenses://reset-password
   ```

4. **Authentication → Providers → Email**
   - Keep *Confirm email* on for production. The app shows a “check your inbox”
     screen after sign-up and lets the user return to login.
   - For local development you can turn confirmation off so new accounts log
     straight in.

5. **Database → Replication** – confirm `transactions`, `categories`,
   `household_members` and `households` are listed under the
   `supabase_realtime` publication (the last migration does this for you).

## 3. Environment variables

The app never contains secrets. Credentials are injected at build time with
`--dart-define`; the only key that ships in the binary is the **anon /
publishable** key, which is designed to be public and is constrained by RLS.
**Never put the service-role key in the app.**

| Variable | Where to find it |
| --- | --- |
| `SUPABASE_URL` | Project Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Project Settings → API → *anon public* key (or the new *publishable* key) |

```bash
cp env.example.json env.json      # then fill in the two values
```

`env.json` is git-ignored. If the app starts without these values it shows a
**Setup required** screen with the same instructions instead of pretending to
be connected.

## 4. Run

```bash
# Android emulator / device or iOS simulator
flutter run --dart-define-from-file=env.json
```

Deep links are registered for both platforms (`jointexpenses://` scheme in
`android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`), so
password-reset e-mails open the in-app **Reset password** screen.

## 5. Build the Android APK (priority)

This machine only needs **Flutter + Android Studio (SDK + platform tools)**.
iOS / App Store comes later and requires a Mac.

### 5.1 One-time Android toolchain

1. Install [Android Studio](https://developer.android.com/studio).
2. Open it once → **More Actions → SDK Manager** and install:
   - SDK Platform **Android 15 (API 35)**
   - **Android SDK Build-Tools**
   - **Android SDK Command-line Tools**
   - **Android SDK Platform-Tools**
3. **Settings → Languages & Frameworks → Android SDK → SDK Tools** → tick
   **Android SDK Command-line Tools (latest)**.
4. Accept the Android licenses from a terminal (PowerShell):

   ```powershell
   $env:PATH = "$env:USERPROFILE\dev\flutter\bin;$env:PATH"
   flutter doctor --android-licenses
   ```

   Press `y` for every license.
5. Confirm the Android line is green:

   ```powershell
   flutter doctor
   ```

   You want `[√] Android toolchain`. Chrome / VS Code being missing is fine.

### 5.2 Point Flutter at the SDK (if doctor still complains)

```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
```

### 5.3 Inject your live Supabase keys, then build

`env.json` must contain the **real** project URL and anon key (never the
service-role key). Those values are compiled into the APK.

```powershell
cd "$env:USERPROFILE\Documents\Projects\Joint Expenses App"
$env:PATH = "$env:USERPROFILE\dev\flutter\bin;$env:PATH"
flutter pub get
flutter build apk --release --dart-define-from-file=env.json
```

The file is written to:

```
build\app\outputs\flutter-apk\app-release.apk
```

Copy it to the phone (USB, Drive, or Telegram) and open it. Android will ask
to **allow installs from this source** the first time.

A single-file APK is enough to share with your partner. Split-per-ABI (smaller
downloads) is optional:

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```

### 5.4 Signing note

The first APK is signed with Flutter's **debug keystore** so you can install
it immediately. That is fine for the two of you. Before Play Store you must
create your own upload keystore (`key.properties` is already git-ignored) —
ask when you are ready and we will wire it.

### 5.5 Other store artifacts (later)

```powershell
flutter build appbundle --release --dart-define-from-file=env.json   # Play Store
# iOS (macOS + Xcode only):
flutter build ipa --release --dart-define-from-file=env.json
```

### First run walkthrough

1. **Sign up** (name, e-mail, password).
2. **Create a household** (name + currency, default PHP) – default categories
   are seeded automatically – **or** **Join** with the 10-character invite code
   your partner generated under *Settings → Members → Invite*.
3. Tap the **+** button to add income or an expense. The dashboard, transactions
   list and categories update instantly on both phones.

## 6. Project structure

```
lib/
├─ main.dart                  entry → bootstrap() → ProviderScope → app
├─ app/                       MaterialApp.router, bootstrap, setup screen
├─ core/
│  ├─ constants/              env, durations/spacing, category icon & colour sets
│  ├─ routing/                GoRouter (auth/onboarding redirects, shell with bottom nav + FAB)
│  ├─ theme/                  M3 light/dark theme, AppColors ThemeExtension
│  ├─ utils/                  Money, CurrencyFormatter, YearMonth/date utils, validators, errors
│  └─ widgets/                AppCard, AnimatedAmount, skeletons, empty/error states, dialogs…
├─ data/
│  ├─ models/                 Profile, Household, HouseholdMember, Category, Transaction…
│  ├─ repositories/           AuthRepository, HouseholdRepository, CategoryRepository, TransactionRepository
│  └─ services/               Supabase client provider, RealtimeSync
└─ features/
   ├─ authentication/         login, sign-up, forgot/reset password, auth providers
   ├─ households/             create/join onboarding, household + members providers
   ├─ dashboard/              DashboardCalculator (pure), summary providers, cards, donut chart
   ├─ transactions/           TransactionFilter (pure), providers, form sheet, detail sheet, list
   ├─ categories/             providers, picker, form sheet (with reassignment on delete), screen
   └─ settings/               theme provider, settings screen, invite sheet
supabase/migrations/          SQL migrations (schema, RLS, RPCs, realtime)
test/                         unit + widget tests (run offline, no backend)
integration_test/             end-to-end test against a real Supabase project
```

Pattern: **feature-first**, with `domain` (pure logic) → `application`
(Riverpod providers/controllers) → `presentation` (widgets), on top of a shared
`data` layer (models + repositories wrapping Supabase). Widgets never call
Supabase directly.

### Realtime & sync

`RealtimeSync` opens **one** channel per household and listens to Postgres
changes on `transactions`, `categories`, `household_members` and `households`.
Changes invalidate the relevant Riverpod providers (debounced 150 ms) so both
phones converge. The channel is torn down when the household changes or the
user signs out; a full refresh runs on reconnect and when the app returns to
the foreground. The transaction controller guards against double-submits so a
double-tap cannot create duplicate records.

### Security model

- RLS on every table; all access is scoped by household membership
  (`is_household_member`, `is_household_owner`, `shares_household_with`).
- `transactions.insert` requires `user_id = auth.uid()` → you can only record
  as yourself; `update`/`delete` only on your own rows.
- Invite codes: 10 characters from an unambiguous alphabet, **only the SHA-256
  hash is stored**, 48-hour expiry, single use, creating a new one invalidates
  older active ones. Joining happens inside a `SECURITY DEFINER` RPC.
- Deleting a category that is in use requires choosing a replacement; the
  reassignment of *both* members' transactions runs server-side
  (`reassign_and_delete_category`) because RLS forbids editing a partner's rows.
- Amount columns are `numeric(14,2) CHECK (> 0)`; a trigger rejects a category
  from another household or of the wrong type.

## 7. Tests

```bash
flutter analyze
flutter test                      # 76 unit + widget tests, no backend needed
```

- `test/unit/` – `Money`, `DashboardCalculator` (totals, balance, per-user and
  per-category totals/percentages, division-by-zero), `TransactionFilter`,
  validators.
- `test/widget/` – login, dashboard, transaction form sheet, transactions
  screen (all Supabase-backed providers are overridden with fixtures).

### Integration tests (real backend)

`integration_test/app_test.dart` logs in, adds income, adds an expense, edits
it, deletes it, then has a **second user** (via a separate `SupabaseClient`)
insert and delete a transaction and asserts that user 1's screen updates
through Realtime.

1. Create two confirmed users in **Authentication → Users**.
2. `cp env.test.example.json env.test.json` and fill in their credentials.
3. Run on a device/emulator:

   ```bash
   flutter test integration_test \
     --dart-define-from-file=env.json \
     --dart-define-from-file=env.test.json
   ```

   The test creates a household for user 1 and joins user 2 through a real
   invite code if they are not already housemates, and removes the rows it
   created when it finishes. Without the dart-defines the test is skipped.

## 8. Design notes & decisions

- **“Paid by / Received by” is read-only.** The spec asked for it to be
  editable, but it also requires that “users can only create transactions as
  themselves”, which is enforced by RLS. The field shows the signed-in user
  with a hint explaining why. Partners can see – but not edit – each other's
  entries.
- **Icons:** categories use Material rounded `Icons` (bundled with Flutter)
  mapped by a stable string key, so no extra font package is needed.
- **Riverpod 2.6** (`Notifier` / `AsyncNotifier`, no code generation) was
  chosen for stability with the current Flutter stable.
- **Currency** is a household setting (default PHP). Formatting uses thousands
  separators and two decimals built from integer parts.
- **Theme**: light by default, dark available, preference persisted locally.

## 9. Troubleshooting

| Symptom | Fix |
| --- | --- |
| “Setup required” screen | You ran without `--dart-define-from-file=env.json` or the file has placeholder values. |
| Sign-up succeeds but login says e-mail not confirmed | Confirm the e-mail or disable *Confirm email* for development. |
| Password-reset link opens the browser instead of the app | Add `jointexpenses://reset-password` to Supabase Redirect URLs. |
| Partner's changes don't appear until refresh | Check the tables are in the `supabase_realtime` publication (migration 3) and Realtime is enabled for the project. |
| `permission denied` / empty lists | Migrations 1 and 2 (RLS + helper functions) were not applied, or the user isn't a household member. |
