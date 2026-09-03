import 'package:flutter_test/flutter_test.dart';
import 'package:rocket_chat_flutter/services/credential_store.dart';

class MemorySecureStorage implements SecureStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  test('secure credential store saves and reloads all login fields', () async {
    final backend = MemorySecureStorage();
    final store = CredentialStore(backend: backend);
    const credentials = SavedCredentials(
      server: 'https://chat.example.com/',
      username: 'coder',
      password: 'secret',
    );

    await store.save(credentials);
    final loaded = await store.load();

    expect(loaded?.server, credentials.server);
    expect(loaded?.username, credentials.username);
    expect(loaded?.password, credentials.password);
    expect(backend.values.values, contains('secret'));
  });

  test('clear removes every stored credential value', () async {
    final backend = MemorySecureStorage();
    final store = CredentialStore(backend: backend);
    await store.save(
      const SavedCredentials(
        server: 'https://chat.example.com/',
        username: 'coder',
        password: 'secret',
      ),
    );

    await store.clear();

    expect(await store.load(), isNull);
    expect(backend.values, isEmpty);
  });

  test('incomplete saved data is rejected and cleared', () async {
    final backend = MemorySecureStorage();
    final store = CredentialStore(backend: backend);
    await store.save(
      const SavedCredentials(
        server: 'https://chat.example.com/',
        username: 'coder',
        password: 'secret',
      ),
    );
    backend.values.remove('rocketchat.saved.password');

    expect(await store.load(), isNull);
    expect(backend.values, isEmpty);
  });
}
