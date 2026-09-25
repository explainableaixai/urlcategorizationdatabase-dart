import 'dart:io';
import 'package:urlcategorizationdatabase/urlcategorizationdatabase.dart';

Future<void> main() async {
  final client = URLCategorizationDatabaseClient(
      apiKey: Platform.environment['AQ_API_KEY'] ?? '');
  try {
    print(await client.classify('bbc.com'));
  } finally {
    client.close();
  }
}
