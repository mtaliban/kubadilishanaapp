/// Mipangilio ya build-time — inawekwa kabla ya runApp() kwenye kila entry point.
///
/// [isAdminBuild] = true  → main.dart  (admin APK — screens zote)
/// [isAdminBuild] = false → main_user.dart (user APK — user screens tu)
class AppConfig {
  static bool isAdminBuild = true;
}
