/// Windows reports `lib\widgets\card.dart` while every lint allowlist spells
/// its paths with forward slashes.
String posixPath(String path) => path.replaceAll(r'\', '/');
