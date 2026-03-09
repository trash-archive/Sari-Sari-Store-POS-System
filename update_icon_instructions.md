# Update App Icon Instructions

## What was done:
1. ✅ Updated invoice screen to use logo.png instead of store icon
2. ✅ Verified logo.png is configured in pubspec.yaml

## To update the app icon (minimap):

Run this command in your terminal:

```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will:
- Generate app icons for Android and iOS using your logo.png
- Update the app icon that appears on the device home screen
- Update the minimap/taskbar icon

## Files updated:
- `lib/features/invoices/ui/invoice_detail_screen.dart` - Now uses logo.png instead of store icon

The logo.png from assets/images/ is now used in both:
1. Invoice receipts (✅ Done)
2. App icon/minimap (⏳ Run the command above)