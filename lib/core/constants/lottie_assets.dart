/// Lottie Animation Assets
/// ملفات الأنيميشن المحلية للأداء الأفضل
///
/// تم نقل جميع الملفات من الإنترنت إلى assets/lottie/ لتحسين الأداء

class LottieAssets {
  LottieAssets._();

  // Base path for all Lottie assets
  static const String _basePath = 'assets/lottie/';

  // ═══════════════════════════════════════════════════════
  // Loading Animations
  // ═══════════════════════════════════════════════════════

  /// تحميل بنقاط
  static const String loadingDots = '${_basePath}loading_dots.json';

  /// تحميل كتاب (تعليمي)
  static const String loadingBook = '${_basePath}loading_book.json';

  /// تحميل بسيط
  static const String loadingSimple = '${_basePath}loading_simple.json';

  /// تحميل Spinner أزرق
  static const String loadingSpinner = '${_basePath}loading_spinner.json';

  /// تحميل دائري بسيط - يستخدم loadingSpinner كبديل
  static const String loadingCircle = loadingSpinner;

  // ═══════════════════════════════════════════════════════
  // Success Animations
  // ═══════════════════════════════════════════════════════

  /// علامة صح ناجحة
  static const String successCheck = '${_basePath}success_check.json';

  /// نجاح مع احتفال
  static const String successCelebration = '${_basePath}success_celebration.json';

  /// نجاح بسيط
  static const String successSimple = '${_basePath}success_simple.json';

  /// تم بنجاح
  static const String successDone = '${_basePath}success_done.json';

  /// نجاح (عام) - يستخدم successCheck
  static const String success = successCheck;

  // ═══════════════════════════════════════════════════════
  // Error Animations
  // ═══════════════════════════════════════════════════════

  /// خطأ - علامة X
  static const String errorCross = '${_basePath}error_cross.json';

  /// خطأ - تحذير
  static const String errorWarning = '${_basePath}error_warning.json';

  /// خطأ بسيط
  static const String errorSimple = '${_basePath}error_simple.json';

  // ═══════════════════════════════════════════════════════
  // Empty State Animations
  // ═══════════════════════════════════════════════════════

  /// صندوق فارغ
  static const String emptyBox = '${_basePath}empty_box.json';

  /// لا توجد بيانات
  static const String emptyData = '${_basePath}empty_data.json';

  /// لا توجد نتائج بحث
  static const String emptySearch = '${_basePath}empty_search.json';

  /// قائمة فارغة
  static const String emptyList = '${_basePath}empty_list.json';

  /// بحث
  static const String search = '${_basePath}search.json';

  // ═══════════════════════════════════════════════════════
  // Education & Learning Animations
  // ═══════════════════════════════════════════════════════

  /// طالب يدرس
  static const String studentStudying = '${_basePath}student_studying.json';

  /// كتب ودراسة
  static const String booksStudy = '${_basePath}books_study.json';

  /// تعليم أونلاين
  static const String onlineLearning = '${_basePath}online_learning.json';

  /// تخرج
  static const String graduation = '${_basePath}graduation.json';

  /// فكرة / مصباح
  static const String idea = '${_basePath}idea.json';

  /// قلم ودفتر - يستخدم booksStudy كبديل
  static const String writing = booksStudy;

  // ═══════════════════════════════════════════════════════
  // Connection & Network
  // ═══════════════════════════════════════════════════════

  /// لا يوجد اتصال بالإنترنت
  static const String noInternet = '${_basePath}no_internet.json';

  /// فقدان الاتصال - يستخدم noInternet كبديل
  static const String connectionLost = noInternet;

  /// جاري الاتصال - يستخدم loadingSpinner كبديل
  static const String connecting = loadingSpinner;

  // ═══════════════════════════════════════════════════════
  // Welcome & Onboarding
  // ═══════════════════════════════════════════════════════

  /// ترحيب
  static const String welcome = '${_basePath}welcome.json';

  /// تطبيق تعليمي - يستخدم onlineLearning كبديل
  static const String educationApp = onlineLearning;

  /// بداية الرحلة
  static const String journey = '${_basePath}journey.json';

  // ═══════════════════════════════════════════════════════
  // Video & Media
  // ═══════════════════════════════════════════════════════

  /// تشغيل فيديو
  static const String videoPlay = '${_basePath}video_play.json';

  /// تحميل فيديو - انيميشن زر تشغيل مع تحميل
  static const String videoLoading = '${_basePath}play_button_loading.json';

  /// زر تشغيل مع تحميل - احترافي
  static const String playButtonLoading = '${_basePath}play_button_loading.json';

  /// بث مباشر
  static const String liveStream = '${_basePath}live_stream.json';

  /// بث مباشر (بديل)
  static const String liveSession = '${_basePath}live_session.json';

  /// تحميل الكتب - يستخدم loadingBook كبديل
  static const String loadingBooks = loadingBook;

  // ═══════════════════════════════════════════════════════
  // Download & Upload
  // ═══════════════════════════════════════════════════════

  /// تحميل ملف - يستخدم loadingSimple كبديل
  static const String download = loadingSimple;

  /// اكتمال التحميل - يستخدم successCheck كبديل
  static const String downloadComplete = successCheck;

  /// رفع ملف - يستخدم loadingSimple كبديل
  static const String upload = loadingSimple;

  // ═══════════════════════════════════════════════════════
  // User & Profile
  // ═══════════════════════════════════════════════════════

  /// ملف شخصي - يستخدم studentStudying كبديل
  static const String profile = studentStudying;

  /// تسجيل دخول - يستخدم welcome كبديل
  static const String login = welcome;

  /// إعدادات - يستخدم idea كبديل
  static const String settings = idea;

  // ═══════════════════════════════════════════════════════
  // Subscription & Payment
  // ═══════════════════════════════════════════════════════

  /// اشتراك بريميوم - يستخدم graduation كبديل
  static const String premium = graduation;

  /// دفع ناجح - يستخدم successCelebration كبديل
  static const String paymentSuccess = successCelebration;

  /// بطاقة ائتمان - يستخدم successCheck كبديل
  static const String creditCard = successCheck;

  // ═══════════════════════════════════════════════════════
  // Notifications
  // ═══════════════════════════════════════════════════════

  /// إشعار جديد - يستخدم idea كبديل
  static const String notification = idea;

  /// جرس إشعارات - يستخدم idea كبديل
  static const String notificationBell = idea;

  /// لا توجد إشعارات - يستخدم emptyBox كبديل
  static const String noNotifications = emptyBox;
}
