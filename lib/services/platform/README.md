# Platform Services

هذه الخدمات توفر دعماً متعدد المنصات (Web + Mobile) للميزات التي تعمل بشكل مختلف على الويب والموبايل.

## الخدمات المتوفرة

### 1. SecureStorageService
بديل لـ `flutter_secure_storage` يعمل على Web و Mobile

**الاستخدام:**
```dart
// بدلاً من:
// final storage = FlutterSecureStorage();

// استخدم:
final storage = SecureStorageService();
await storage.init();

// نفس الواجهة:
await storage.write(key: 'token', value: 'xxx');
final token = await storage.read(key: 'token');
await storage.delete(key: 'token');
```

**الآلية:**
- **Mobile**: يستخدم `flutter_secure_storage` (آمن ومشفر)
- **Web**: يستخدم `SharedPreferences` (متزامن مع localStorage)

### 2. FileStorageService
بديل لـ `path_provider` مع دعم محدود للويب

**الاستخدام:**
```dart
final fileService = FileStorageService();

if (fileService.supportsFileSystem) {
  final path = await fileService.getVideoStoragePath();
  // استخدم File system
} else {
  // استخدم IndexedDB أو Cache API على الويب
}
```

**ملاحظة:** الويب لا يدعم File system التقليدي، استخدم:
- `IndexedDB` لتخزين البيانات الثنائية (فيديوهات)
- `Cache API` للتخزين المؤقت
- `LocalStorage` للبيانات النصية البسيطة

### 3. DeviceInfoService
بديل لـ `device_info_plus` مع دعم كامل للويب

**الاستخدام:**
```dart
final deviceInfo = DeviceInfoService();

final deviceId = await deviceInfo.getDeviceId();
final deviceName = await deviceInfo.getDeviceName();
final isWeb = deviceInfo.isWeb;

if (isWeb) {
  // الويب: deviceId هو browser fingerprint
} else {
  // الموبايل: deviceId هو Android ID الفعلي
}
```

## ملاحظات مهمة للويب

### تنزيل الفيديوهات
على الويب، لا يمكن تنزيل ملفات مشفرة بنفس طريقة الموبايل. البدائل:
1. **Cache API**: تخزين مؤقت للفيديوهات
2. **IndexedDB**: تخزين دائم للبيانات الثنائية
3. **Service Worker**: تخزين ذكي في الخلفية

### Device Binding
على الويب:
- لا يوجد Device ID ثابت
- استخدم Browser Fingerprinting (تقريبي)
- أو Session-based authentication

### Permissions
`permission_handler` لا يعمل بالكامل على الويب.
استخدم Web APIs مباشرة:
- **Camera**: `navigator.mediaDevices.getUserMedia()`
- **Notifications**: `Notification.requestPermission()`
- **Location**: `navigator.geolocation.getCurrentPosition()`

## الخطوات التالية

عند تحديث الكود الحالي:
1. ابحث عن `FlutterSecureStorage()` واستبدله بـ `SecureStorageService()`
2. ابحث عن `getApplicationDocumentsDirectory()` وتحقق من platform
3. ابحث عن `DeviceInfoPlugin()` واستبدله بـ `DeviceInfoService()`
4. أضف platform checks حيث ضروري
