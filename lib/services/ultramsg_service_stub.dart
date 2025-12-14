/// Stub for UltraMsg service on web
/// Web apps should use SecureOTPService which uses Edge Functions
class UltraMsgService {
  UltraMsgService() {
    throw UnsupportedError(
      'UltraMsgService is not supported on web. '
      'Use SecureOTPService instead.'
    );
  }
}
