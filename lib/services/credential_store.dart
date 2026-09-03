import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentials {
  const SavedCredentials({
    required this.server,
    required this.username,
    required this.password,
  });

  final String server;
  final String username;
  final String password;
}

abstract interface class SecureStorageBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStorageBackend implements SecureStorageBackend {
  FlutterSecureStorageBackend({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(migrateWithBackup: true),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class CredentialStore {
  CredentialStore({SecureStorageBackend? backend})
    : _backend = backend ?? FlutterSecureStorageBackend();

  static const _serverKey = 'rocketchat.saved.server';
  static const _usernameKey = 'rocketchat.saved.username';
  static const _passwordKey = 'rocketchat.saved.password';
  static const _enabledKey = 'rocketchat.saved.enabled';

  final SecureStorageBackend _backend;

  Future<SavedCredentials?> load() async {
    if (await _backend.read(_enabledKey) != 'true') return null;
    final values = await Future.wait([
      _backend.read(_serverKey),
      _backend.read(_usernameKey),
      _backend.read(_passwordKey),
    ]);
    if (values.any((value) => value == null || value.isEmpty)) {
      await clear();
      return null;
    }
    return SavedCredentials(
      server: values[0]!,
      username: values[1]!,
      password: values[2]!,
    );
  }

  Future<void> save(SavedCredentials credentials) async {
    await _backend.write(_serverKey, credentials.server);
    await _backend.write(_usernameKey, credentials.username);
    await _backend.write(_passwordKey, credentials.password);
    await _backend.write(_enabledKey, 'true');
  }

  Future<void> clear() async {
    await _backend.delete(_enabledKey);
    await _backend.delete(_passwordKey);
    await _backend.delete(_usernameKey);
    await _backend.delete(_serverKey);
  }
}
