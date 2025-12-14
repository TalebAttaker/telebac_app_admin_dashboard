/// Supabase Configuration
/// Contains all Supabase connection details and API keys

class SupabaseConfig {
  // Supabase Project Configuration
  static const String supabaseUrl = 'https://ctupxmtreqyxubtphkrk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0dXB4bXRyZXF5eHVidHBoa3JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyMjQxMTUsImV4cCI6MjA3ODgwMDExNX0.Clwx6EHcakWAh_6WFdljsvFD_TKh33QclATuIgdRcnM';

  // Edge Functions Base URL
  static const String functionsUrl = '$supabaseUrl/functions/v1';

  // Edge Function Endpoints
  static const String checkAccessEndpoint = '$functionsUrl/check-access';
  static const String generateVideoTokenEndpoint = '$functionsUrl/generate-video-token';
  static const String trackProgressEndpoint = '$functionsUrl/track-progress';
  static const String analyticsTrackEndpoint = '$functionsUrl/analytics-track';
  static const String liveSessionEndpoint = '$functionsUrl/live-session';

  // BunnyCDN Configuration
  static const String bunnyCdnBaseUrl = 'https://mauritania-edu.b-cdn.net';

  // Jitsi Configuration
  static const String jitsiDomain = 'meet.jit.si';

  // App Configuration
  static const String appName = 'El-Mouein';
  static const String appVersion = '1.0.0';

  // Feature Flags
  static const bool enableOfflineDownloads = true;
  static const bool enableLiveStreaming = true;
  static const bool enablePushNotifications = true;

  // Video Player Settings
  static const int videoBufferDuration = 30; // seconds
  static const int progressUpdateInterval = 10; // seconds

  // Cache Settings
  static const int imageCacheDuration = 7; // days
  static const int videoCacheDuration = 30; // days
}
