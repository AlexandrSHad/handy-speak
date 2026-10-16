/// The app's marketing version — the part of `pubspec.yaml`'s `version:`
/// before the `+build` suffix (`0.6.0+1` → `0.6.0`).
///
/// Hand-maintained on purpose: the only consumer is the cosmetic version
/// label at the foot of the Settings rail, and a `package_info_plus`
/// platform-channel dependency is not worth that.
///
/// It MUST match `pubspec.yaml`. `test/app_version_test.dart` reads the
/// pubspec and pins the two together, so bumping one without the other
/// fails the headless test run.
const String kAppVersion = '0.8.0';
