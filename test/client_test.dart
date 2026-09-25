import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:urlcategorizationdatabase/urlcategorizationdatabase.dart';

void main() {
  test('decodes a successful response', () async {
    final mock = MockClient((request) async {
      expect(request.url.path, contains('iab_web_content_filtering.php'));
      return http.Response('{"ok":true}', 200);
    });
    final client = URLCategorizationDatabaseClient(
        apiKey: 'test', baseUrl: 'https://example.test/api', httpClient: mock);
    final result = await client.classify('bbc.com');
    expect(result['ok'], isTrue);
  });
}
