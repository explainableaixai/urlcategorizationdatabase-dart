# urlcategorizationdatabase

Teams that license a URL category database load it into their own systems and match against it offline. That covers the domains in the file. It does not cover the domain registered last Tuesday, or the long tail of small sites a crawler reaches first. This Dart package fills that gap: it sends one URL to the live classifier and returns its categories, so your pipeline can label what the file did not contain.

Product details, coverage and file formats are on the [URL categorization data for offline matching](https://www.urlcategorizationdatabase.com) site.

## Install

```bash
dart pub add urlcategorizationdatabase
```

## One URL

```dart
import 'package:urlcategorizationdatabase/urlcategorizationdatabase.dart';

final client = URLCategorizationDatabaseClient(apiKey: key);
final result = await client.classify('bbc.com');
print(result.toJson());
client.close();
```

`classify` accepts a domain or a full URL. The service reads the page, assigns categories from the IAB content taxonomy, and returns them with confidence scores. The exact response fields are listed in the API reference on the website. The client does not reshape them, so new fields appear in your code as soon as the service adds them.

## The pattern this package is built for

Most users combine three steps: check the local file, fall back to the API on a miss, and remember the answer.

```dart
class Categorizer {
  Categorizer(this.local, this.api);

  final Map<String, List<String>> local; // loaded from the licensed file
  final URLCategorizationDatabaseClient api;
  final _learned = <String, ApiResult>{};

  Future<Object> categorize(String domain) async {
    final hit = local[domain];
    if (hit != null) return hit;
    return _learned[domain] ??= await api.classify(domain);
  }
}
```

Persist `_learned` between runs, for example as a JSON file or a table, and merge it into the next import. Over a few weeks that builds a supplement that fits your own traffic.

## Domain or full URL?

Send a domain when you want one label for a whole site, which is what most filtering and analytics jobs need. Send a full URL when sections of a site differ, as on news portals, marketplaces and hosting platforms where thousands of unrelated sites share one parent domain.

A useful rule: normalise to the registered domain for storage keys, but keep the original URL next to it. If a domain later turns out to be a shared host, you can reclassify its individual URLs without collecting them again.

## Normalising input before you send it

The client sends exactly the string you give it. Cleaning input first saves quota and gives steadier results:

```dart
String normalise(String raw) {
  var s = raw.trim().toLowerCase();
  if (!s.contains('://')) s = 'https://$s';
  final u = Uri.parse(s);
  final host = u.host.startsWith('www.') ? u.host.substring(4) : u.host;
  return host;
}
```

Lower-casing and stripping `www.` alone often removes a noticeable share of duplicate calls in real logs.

## Keeping the supplement fresh

Sites change what they are about. A parked domain becomes a shop, and a hobby blog turns into a news site. Store a date with every learned category and reclassify entries older than a few months. The licensed file is refreshed on its own schedule, so when a new release arrives, drop learned entries that the file now covers. The file is the reference, and your supplement only fills gaps.

## Batches

The client handles one URL per call. For a batch, run a few calls at a time rather than all at once:

```dart
Future<List<ApiResult>> classifyAll(
    URLCategorizationDatabaseClient c, List<String> urls,
    {int width = 4}) async {
  final out = <ApiResult>[];
  for (var i = 0; i < urls.length; i += width) {
    final slice = urls.skip(i).take(width);
    out.addAll(await Future.wait(slice.map(c.classify)));
  }
  return out;
}
```

A width of four is gentle on the service and still quick. If you see `RateLimitException`, lower it.

## Where the categories go next

The labels are a means to an end. Common uses:

- **Ad and brand safety.** Mark pages as suitable or unsuitable before a bid or placement.
- **Analytics.** Group visits or clicks by what the destination is about.
- **Security.** Feed categories into a proxy or DNS policy that allows or blocks by topic.
- **Data cleaning.** Tag a list of company websites by industry before a sales team uses it.

For the security case, pair content categories with [filtering categories mapped to policy actions](https://www.webfilteringdatabase.com), which are designed for allow and block decisions rather than topic labels.

## Things the client does and does not do

It does:

- send your key in the request body, as the endpoint expects
- apply a timeout (30 seconds unless you pass another)
- turn HTTP errors into typed exceptions
- let you inject your own `http.Client`

It does not:

- retry failed calls
- cache anything
- validate that a string is a real domain before sending it

Those choices keep the package small and predictable. The caching example above shows how little code the missing pieces take.

## Exceptions

```dart
try {
  await client.classify(url);
} on AuthenticationException {
  // 401 or 403: check the key and the plan's remaining quota
} on RateLimitException {
  // 429: slow down and try later
} on ApiException catch (e) {
  // anything else; e.statusCode and e.body say more
}
```

`ArgumentError` is raised for an empty key or empty input before any request.

## Configuration in tests and staging

Point `baseUrl` at a stub server, or pass a `MockClient`:

```dart
final client = URLCategorizationDatabaseClient(
  apiKey: 'test',
  httpClient: MockClient((_) async => http.Response('{"categories":[]}', 200)),
);
```

That keeps unit tests offline and fast.

## Beyond content categories

Two questions come up often once categories are flowing:

- Which of these sites are AI tools? The general taxonomy treats them as software. To [separate AI assistants from ordinary SaaS](https://www.aitoolsblocklist.com), check them against a dedicated register.
- How much AI use is there across the organisation? Existing DNS or proxy logs can [measure AI adoption from existing logs](https://www.shadowaitools.com) without new agents on endpoints.

## Other packages

- [npm: urlcategorizationdatabase](https://www.npmjs.com/package/urlcategorizationdatabase)
- [Rust crate](https://crates.io/crates/urlcategorizationdatabase)
- [PHP on Packagist](https://packagist.org/packages/urlcategorizationdatabase/urlcategorizationdatabase)

## License

MIT. Categories follow the IAB Tech Lab Content Taxonomy, which is referenced here for compatibility only.
