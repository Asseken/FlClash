/// Windows reports `lib\views\card.dart` while every scan spells its allowlist
/// and its skip rules with forward slashes.
String posixPath(String path) => path.replaceAll(r'\', '/');
