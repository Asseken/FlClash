import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/core_update.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

final _rawReleases = <Map<String, dynamic>>[
  {'tag_name': 'v1.9.28', 'body': 'older'},
  {'tag_name': 'v1.19.30', 'body': 'newest stable'},
  {'tag_name': 'v1.19.31-beta', 'body': 'pre-release'},
  {'tag_name': '', 'body': 'no tag'},
  {'body': 'no tag key'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseReleases', () {
    test('keeps stable tags newest first and drops the rest', () {
      final releases = CoreUpdate.parseReleases(_rawReleases);

      expect(releases.map((release) => release.tagName), [
        'v1.19.30',
        'v1.9.28',
      ]);
      expect(releases.first.version, '1.19.30');
      expect(releases.first.body, 'newest stable');
    });

    test('reports nothing when the request failed', () {
      expect(CoreUpdate.parseReleases(null), isEmpty);
    });
  });

  group('resolve', () {
    final releases = CoreUpdate.parseReleases(_rawReleases);

    test('flags only releases newer than the running Core', () {
      final outdated = CoreUpdate.resolve(releases, '1.9.28');

      expect(outdated.hasUpdate, isTrue);
      expect(outdated.newerReleases.map((release) => release.version), [
        '1.19.30',
      ]);

      final upToDate = CoreUpdate.resolve(releases, '1.19.30');

      expect(upToDate.hasUpdate, isFalse);
      expect(upToDate.newerReleases, isEmpty);
    });

    test('does not flag an update while the running version is unknown', () {
      final data = CoreUpdate.resolve(releases, '');

      expect(data.hasUpdate, isFalse);
      expect(data.newerReleases, releases);
      expect(data.latest?.tagName, 'v1.19.30');
    });
  });

  test('keeps the state empty when the release request fails', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final interceptor = InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
      },
    );
    request.dio.interceptors.add(interceptor);
    addTearDown(() => request.dio.interceptors.remove(interceptor));

    await container.read(coreUpdateProvider.notifier).check();

    expect(container.read(coreUpdateProvider).releases, isEmpty);
  });
}
