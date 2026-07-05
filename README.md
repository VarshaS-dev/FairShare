# FairShare

A free, modern expense-splitting app. Split bills fairly with friends, roommates,
and travel groups — see who owes whom, and settle up without the awkwardness.

> 🚧 Early development, built slice by slice.

## Tech stack
- **Mobile:** Flutter · Dart · Riverpod · GoRouter · Dio
- **Backend:** FastAPI · PostgreSQL *(arriving in Slice 2)*
- **Auth & messaging:** Firebase Authentication · Firebase Cloud Messaging

## Repository layout
```
FairShare/
├─ mobile/    # Flutter app
├─ backend/   # FastAPI service (coming in Slice 2)
└─ docs/      # notes & decisions
```

## Progress
- ✅ **Slice 0 — Foundation:** Material 3 theme (light + dark), GoRouter shell, Riverpod.
- ✅ **Slice 1 — Auth:** Firebase email/password + Google sign-in, route guard.
- ⏭️ **Slice 2 — Groups:** create/list groups; backend enters.

## Running (web, during development)
```bash
cd mobile
flutter run -d chrome
```
Requires the Flutter SDK. The web Firebase config is included; Android setup
comes with a later slice.

## Architecture
The Flutter app uses a **feature-first** structure with light layering:
`presentation` (widgets) → `application` (Riverpod state) → `data` (repositories).
Firebase owns identity; the FastAPI backend (from Slice 2) owns everything else,
keyed by the user's Firebase UID.
