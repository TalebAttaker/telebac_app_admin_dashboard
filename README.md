# TeleBac Admin Dashboard

**لوحة تحكم مدير منصة تيليباك التعليمية**

## Overview

This is the administrative dashboard for the TeleBac educational platform, separated from the main PWA application for better maintainability and security.

## Features

- Secure admin authentication system
- User management
- Content management (videos, PDFs, lessons)
- Subscription management
- Payment verification
- Live streaming management
- Curriculum and grade management
- Subject and topic management
- Notification system
- Analytics and statistics

## Tech Stack

- **Framework**: Flutter (Web PWA)
- **Backend**: Supabase
- **Storage**: BunnyCDN
- **State Management**: Provider
- **Authentication**: Supabase Auth with Admin role verification

## Prerequisites

- Flutter SDK (>=3.0.0)
- Supabase account and project
- BunnyCDN account (for video storage)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/TalebAttaker/telebac_app_admin_dashboard.git
cd telebac_app_admin_dashboard
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Supabase:
   - Update `lib/config/supabase_config.dart` with your Supabase credentials
   - Run migrations in `supabase/migrations/`

4. Run the app:
```bash
flutter run -d chrome
```

## Project Structure

```
lib/
├── config/              # Configuration files (Supabase, etc.)
├── core/                # Core utilities and themes
├── models/              # Data models
├── screens/
│   ├── admin/          # All admin dashboard screens
│   └── auth/           # Admin login screen
├── services/           # Business logic and API services
├── utils/              # Utility functions and themes
└── widgets/            # Reusable widgets
    └── admin/          # Admin-specific widgets
```

## Key Screens

- **Modern Admin Dashboard**: Main dashboard with statistics
- **Users Management**: Manage user accounts and subscriptions
- **Video Manager**: Upload and manage educational videos
- **Payment Verification**: Approve/reject subscription payments
- **Live Stream Management**: Create and manage live sessions
- **Curriculum Management**: Organize educational content
- **Notification Center**: Send push notifications to users

## Security

- Role-based access control (Admin only)
- Secure authentication with Supabase
- Row Level Security (RLS) policies
- Protected routes and API endpoints

## Environment Variables

Required configuration in `lib/config/supabase_config.dart`:
- Supabase URL
- Supabase Anon Key
- BunnyCDN credentials (for video upload)

## Deployment

This app is designed to run as a PWA. Deploy to:
- Netlify
- Vercel
- Firebase Hosting
- Any static hosting provider

## Admin Access

To access the dashboard:
1. You must have an account with `is_admin: true` in the `profiles` table
2. Login using admin credentials
3. System will verify admin status before granting access

## Contributing

This is a private project for the TeleBac educational platform.

## License

Proprietary - All rights reserved

## Contact

For support or inquiries, contact the development team.

---

**Built with Flutter & Supabase**
