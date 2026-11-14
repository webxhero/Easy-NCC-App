# Easy NCC — Project Guide (বাংলা)

## ১. Project কী?

Easy NCC হলো BNCC-এর Activity, Cadet Profile, Uniform Measurement এবং Training Progress পরিচালনার জন্য Phase 1 Management Platform। একই Flutter Codebase থেকে Android App ও Web App Build করা যাবে। দুই Platform একই Supabase Backend ব্যবহার করবে।

## ২. ব্যবহৃত Technology

| Technology | ব্যবহার |
|---|---|
| Flutter | Android ও Web UI |
| Dart | মূল Programming Language |
| Material 3 | UI Component ও Theme |
| Google Sans | App Typography |
| Riverpod | Dependency / Repository Provider |
| Supabase Auth | Registration, Login, Session |
| PostgreSQL | Cloud Database |
| RLS | Database Security |
| PDF + Printing | A4 Measurement Card ও Report |
| File Picker | JSON Import |
| Share Plus | JSON / CSV Export |

## ৩. Branding

- App Name: Easy NCC
- Logo: `assets/branding/bncc_logo.png`
- Dark Green: `#0B2D1B`
- Brand Green: `#0F3822`
- Mid Green: `#164E30`
- Light Green: `#1E633D`
- Gold: `#D6A855`
- Background: `#F3F6F4`

মূল BNCC Activity APK-এর Green-Gold Theme অনুসরণ করা হয়েছে। Measurement Generator ZIP-এর Measurement Field, Edit/Delete, A4 Print, 9/12 Cards, JSON Import/Export ধারণাগুলো Flutter UI-তে নেওয়া হয়েছে।

## ৪. Folder অনুযায়ী কাজ

### `lib/main.dart`
Flutter চালু করে। Supabase URL ও Publishable Key `lib/core/app_config.dart`-এর constant থেকে পড়ে। Credentials বসানো থাকলে Supabase Initialize হয়, না থাকলে Setup / Demo Preview দেখায়।

### `lib/app.dart`
MaterialApp, Theme, ScrollBehavior এবং AuthGate রাখে। AuthGate দেখে User Login করেছে কি না। Login না থাকলে Login Page, Login থাকলে Profile লোড করে MainShell দেখায়।

### `lib/core/`
- `app_colors.dart`: Brand Color এক জায়গায় রাখে।
- `app_theme.dart`: Material 3 ও Google Sans Theme। `google_fonts: ^8.2.1` ব্যবহার করে Flutter-এর নিজস্ব TextTheme-এর সঙ্গে compatibility রাখা হয়েছে।
- `app_config.dart`: Supabase Project URL ও Publishable Key একবার এখানে বসাতে হবে; এরপর Run/Build Command-এ আর Key দিতে হয় না।
- `app_providers.dart`: Riverpod Provider।
- `app_scroll_behavior.dart`: Touch ও Mouse Scroll Support এবং Bouncing Physics।
- `app_widgets.dart`: Logo, Page Heading, Stat Card, Empty/Error State, Date Format ইত্যাদি reusable Widget।

### `lib/data/easy_ncc_repository.dart`
সব Supabase Query এবং Data Write এই Repository-তে থাকে। UI সরাসরি Supabase Table Query করে না। Supabase Key না থাকলে Demo Preview-এর in-memory sample data ব্যবহার করে; Demo Data Cloud-এ Save হয় না।

### `lib/features/auth/`
Login, Open Registration, Password Reset এবং Public Central Activity দেখার Entry Point। নতুন User-এর Role SQL Trigger দিয়ে `member` হয়।

### `lib/features/shell/`
Responsive Navigation। ছোট Screen-এ Bottom Navigation, বড় Screen-এ NavigationRail।

### `lib/features/dashboard/`
Total Cadet, Activity, Completed, Upcoming, Overdue, Training ও Latest Notice-এর Summary।

### `lib/features/events/`
Original Activity APK-এর Event Name, Date, Complete Toggle, Filter, Search, Note এবং Delete Functionality। Visibility দুই রকম: Personal ও Central।

### `lib/features/measurements/`
Measurement ZIP-এর Name, Cadet Number, 7 Shirt Field ও 6 Pant Field, Add/Edit/Delete/Search, 9 বা 12 Cards per A4 Page, PDF Preview, JSON Import/Export।

### `lib/features/notices/`
Admin ও Supervisor Notice Publish করতে পারে। Member Published Notice পড়তে পারে।

### `lib/features/cadets/`
Registered Profile Directory, Search, Admin Role Change এবং Supervisor Assignment।

### `lib/features/training/`
Admin/Supervisor Cadet-এর Training Record Assign করে; Member নিজের Progress দেখে।

### `lib/features/reports/`
Role অনুযায়ী অনুমোদিত Data থেকে Summary, Status Bar, PDF এবং CSV Export।

## ৫. Database Table

| Table | কী রাখে |
|---|---|
| `profiles` | Account Profile ও Role |
| `supervisor_assignments` | Supervisor-এর সঙ্গে Cadet Assignment |
| `events` | Personal ও Central Activity |
| `event_notes` | Activity Note |
| `measurements` | Shirt ও Pant Measurement |
| `notices` | Notice ও Announcement |
| `training_records` | Cadet Training Progress |

`supabase/schema.sql` ফাইলে Table, Trigger, Index, Grant ও RLS Policy আছে। নতুন Supabase Project-এ SQL Editor দিয়ে পুরো ফাইল একবার Run করতে হবে।

## ৬. User Role

### Admin
সব Management Data ও Role পরিচালনা করে। Supervisor Promote এবং Cadet Assign করতে পারে।

### Supervisor
Admin যেসব Cadet Assign করেন, তাদের Measurement ও Training পরিচালনা করতে পারে। Notice Publish করতে পারে।

### Member
নিজের Personal Activity, নিজের Measurement ও Training Progress দেখতে পারে। Central Activity তৈরি করতে পারে এবং Published Notice / Cadet Directory দেখতে পারে।

## ৭. Personal ও Central Activity-এর পার্থক্য

- Personal: Owner ছাড়া অন্য Member দেখতে পাবে না। Admin Management Access পাবে।
- Central: Login ছাড়াও Internet-এর Visitor দেখতে পারবে। Create করতে Login লাগে।
- Added By Name Database Trigger থেকে Profile Name নিয়ে সেট করে। Email Public করা হয় না।
- Central Activity বা Note-এ ব্যক্তিগত তথ্য দেওয়া যাবে না।

## ৮. Supabase Setup

1. Supabase Project তৈরি করুন।
2. `supabase/schema.sql` SQL Editor-এ Run করুন।
3. App থেকে প্রথম Account Register করুন।
4. Auth Users থেকে UUID কপি করুন।
5. SQL Editor-এ `profiles.role='admin'` করুন।
6. Admin Account দিয়ে Login করুন।
7. Directory থেকে Supervisor Role ও Assignment সেট করুন।

## ৯. Run ও Build

প্রথমে Flutter SDK থেকে Android/Web Platform Folder Generate করুন। এই Project-এ `setup_windows.bat` রাখা হয়নি; নিচের দুইটি Command Terminal-এ নিজে চালান:

```bash
flutter create --platforms=android,web --org com.easyncc --project-name easy_ncc .
flutter pub get
```

Supabase URL ও Publishable Key `lib/core/app_config.dart`-এ একবার বসিয়ে Save করুন। তারপর নিচের সাধারণ Command-গুলো ব্যবহার করুন। Placeholder রেখে দিলে Demo Preview চালু হবে।

Web-এ Run (Supabase Configure করা থাকলে Live Data, না থাকলে Demo Preview):

```bash
flutter run -d chrome
```

Android APK:

```bash
flutter build apk --release
```

Web Build:

```bash
flutter build web --release
```

## ১০. Security

- `service_role` বা Secret Key কখনো App-এ দেওয়া যাবে না।
- Public Central Activity ছাড়া Personal Task Public নয়।
- Measurement ও Training Data RLS দিয়ে সুরক্ষিত।
- Role পরিবর্তন শুধু Admin করতে পারে; Database Trigger Self-Promotion আটকায়।
- Production-এ ব্যবহারের আগে আলাদা Admin, Supervisor ও Member Account দিয়ে RLS Test করতে হবে।

## ১১. যাচাই

এই Source Package তৈরি করার পরিবেশে Flutter SDK ছিল না। তাই এখানে `flutter pub get`, `flutter analyze` বা APK/Web Build চালানো সম্ভব হয়নি। PC-তে Flutter SDK Install করার পর এই তিনটি ধাপ চালিয়ে Environment-level Verification সম্পন্ন করতে হবে।
