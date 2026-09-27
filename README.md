# Roommate+

An iOS app for sharing a household: whose turn it is to buy groceries, who's home, and who owes whom. Built with SwiftUI and backed by [Supabase](https://supabase.com), with live sync between roommates' phones.

## Features

- **Status**: each roommate sets a presence or mood. Everyone sees it with a "5m ago" style timestamp.
- **Grocery rotation**: shared items such as paper towels and dish soap rotate round-robin between roommates. When someone marks an item bought, it passes to the next active person. Paused roommates are skipped, and every purchase is logged to history.
- **Split**: log a shared expense and split it equally. Leftover cents go to the first participants. The tab shows net balances between roommates and deep-links to Venmo, or copies Zelle details, so people can settle up.
- **Household info**: members, profile photos, payment handles, pausing your turns (for example while traveling), and a light or dark appearance setting.
- **Join codes**: invite roommates to a household with a short code.
- **Realtime sync**: changes appear on every phone through Supabase Realtime. The app also polls every 20 seconds as a fallback.
- **Notifications**: a local notification tells a roommate when an item becomes theirs, and another celebrates when an item is fulfilled.

## Tech stack

| | |
|---|---|
| UI | SwiftUI (iOS 26.5+) |
| Backend | Supabase: Postgres, Realtime, Storage |
| SDK | [`supabase-swift`](https://github.com/supabase/supabase-swift) v2, via Swift Package Manager |
| Design | A monday.com-inspired design system (`Design/MondayDesign.swift`) |

## Project structure

```
Roommate+/
├── Roommate+/
│   ├── Roommate_App.swift       # App entry: restore session → setup or main tabs
│   ├── Models/                  # Household, User, Item, History, SplitExpense, RoommateStatus
│   ├── Services/                # AuthService, RotationService, RealtimeService, NotificationService
│   ├── Views/                   # Tab screens and sheets
│   ├── Design/                  # Colors, typography, appearance manager
│   ├── Utils/                   # Supabase config, dates, avatars, payment links
│   └── Secrets.example.plist    # Template for your Supabase credentials
├── Roommate+Tests/
├── Roommate+UITests/
└── Design Elements/             # Design reference specs
supabase/
├── rls_policies.sql             # Tables, RLS policies, realtime publication, avatars bucket
└── reset_data.sql               # Wipe all rows (keeps the schema)
```

## Getting started

### Prerequisites

- Xcode 26 or later
- A free [Supabase](https://supabase.com) project

### 1. Set up the database

In your Supabase project, open **SQL Editor** and run [`supabase/rls_policies.sql`](supabase/rls_policies.sql). The script:

- creates the `households`, `users`, `items`, `join_codes`, `history`, `expenses`, and `expense_participants` tables
- applies row-level security policies
- adds the tables to the `supabase_realtime` publication
- creates a public `avatars` storage bucket for profile photos

The script is safe to re-run.

### 2. Add your credentials

```sh
cp "Roommate+/Roommate+/Secrets.example.plist" "Roommate+/Roommate+/Secrets.plist"
```

Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Both are in the Supabase dashboard under **Project Settings → API**. Use the publishable (anon) key. Never put the `service_role` key in the app.

Git ignores `Secrets.plist`. Xcode bundles it automatically because the project uses synchronized folders.

### 3. Build and run

1. Open `Roommate+/Roommate+.xcodeproj` in Xcode.
2. Under **Signing & Capabilities**, select your own development team.
3. Run on a simulator or a device.

Swift Package Manager resolves `supabase-swift` on the first build.

## Resetting test data

Run [`supabase/reset_data.sql`](supabase/reset_data.sql) in the SQL Editor. It clears every row and keeps the tables and policies.
