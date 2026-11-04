/// Defaults to the deployed backend at https://e-radio.devams.site. Override
/// at build/run time with --dart-define=API_BASE_URL=... — e.g. a local
/// backend (php artisan serve --host=0.0.0.0) needs the dev machine's LAN IP
/// on a physical device, or http://10.0.2.2:8000/api on an Android emulator.   P-02xd%*tA7U?d-A
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://e-radio.devams.site/api',
  );

  /// The AMS program site's API, where Apsara FM97 and FM99 keep their weekly
  /// schedule (not part of our own API). Both stations are asked at this one
  /// address, each for the programs filed under its own id. Override at
  /// build/run time with --dart-define=APSARA_PROGRAMS_URL=...
  static const apsaraProgramsUrl = String.fromEnvironment(
    'APSARA_PROGRAMS_URL',
    defaultValue: 'https://radio.amskh.co/wp-json/wp/v2/programs',
  );

  /// The Google Cloud OAuth "Web application" client ID that "Continue with
  /// Google" asks Google for ID tokens for — the same one the backend lists in
  /// GOOGLE_CLIENT_IDS. Empty until it is set, and "Continue with Google" then
  /// says "Coming soon". Pass --dart-define=GOOGLE_SERVER_CLIENT_ID=... or put
  /// it here as the default; it is an identifier, not a secret.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '25529439181-1l7tm83bjkrn7r1b3j2ncdur2k3hc9et.apps.googleusercontent.com',
  );
}
