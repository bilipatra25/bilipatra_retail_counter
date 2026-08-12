# Bilipatra Retail Counter POS

This is the Retail Counter POS (Point of Sale) Flutter application. It provides an interface for managing in-store retail sales, processing offline and online payments (via QR), and handling customer credit accounts.

## 🚀 Getting Started

To run the application locally:
1. Ensure you have the Flutter SDK installed.
2. Run `flutter pub get` to install dependencies.
3. Use `flutter run` to launch the app on your connected device or emulator.

## 📲 App Distribution Standard Practice

When a new version of the frontend client (e.g., this POS App) is released, you must update the backend database configuration so the application can enforce version checks and provide download links for the update.

Execute the following SQL queries in the backend database to update the required configuration values (example for version `1.0.7`):

```sql
UPDATE b12greenStoreLocator.tbl_configuration
	SET configuration_value='1.0.7'
	WHERE configuration_id=8;
    
UPDATE b12greenStoreLocator.tbl_configuration
	SET configuration_value='1.0.7'
	WHERE configuration_id=7;
    
UPDATE b12greenStoreLocator.tbl_configuration
	SET configuration_value='https://drive.google.com/file/d/1ymsFKw3Z2VKsL_cwT8yqN2Lv4F0KSCUN/view?usp=sharing'
	WHERE configuration_id=6;
```
