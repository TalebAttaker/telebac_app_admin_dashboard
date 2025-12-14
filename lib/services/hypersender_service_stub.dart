/// Stub for Hypersender service on web
/// Web apps should use SecureOTPService which uses Edge Functions
class HypersenderService {
  HypersenderService() {
    throw UnsupportedError(
      'HypersenderService is not supported on web. '
      'Use SecureOTPService instead.'
    );
  }
}
