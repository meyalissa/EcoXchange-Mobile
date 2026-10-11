// EcoXchange Mobile — EditPersonalInfoProvider (Personal Information
// editing, shared by Customer + Rider). Repository/AuthProvider faked by
// subclassing/constructing for real — no HTTP/Dio call ever happens, and
// `image_picker`'s real platform channel is never touched (the provider's
// own `debugUploadPhotoAt` seam drives the upload logic directly, exactly
// mirroring AiScanProvider's established convention).

import 'package:flutter_test/flutter_test.dart';

import 'package:ecoxchange_mobile/core/api/api_client.dart';
import 'package:ecoxchange_mobile/core/api/api_exception.dart';
import 'package:ecoxchange_mobile/features/auth/data/auth_repository.dart';
import 'package:ecoxchange_mobile/features/auth/data/models/user_model.dart';
import 'package:ecoxchange_mobile/features/auth/data/profile_repository.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/auth_provider.dart';
import 'package:ecoxchange_mobile/features/auth/presentation/providers/edit_personal_info_provider.dart';
import 'package:ecoxchange_mobile/core/storage/token_storage.dart';

UserModel _user({
  String name = 'Nurul Aisyah binti Ahmad',
  String email = 'customer@ecoxchange.com',
  String? phoneNumber = '+60123456780',
  String? profilePhotoUrl,
}) =>
    UserModel(id: 20, name: name, email: email, role: 'customer', phoneNumber: phoneNumber, profilePhotoUrl: profilePhotoUrl);

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository({this.updateResult, this.photoResult, this.updateError, this.photoError}) : super(ApiClient());

  final UserModel? updateResult;
  final UserModel? photoResult;
  final ApiException? updateError;
  final ApiException? photoError;
  int updateCalls = 0;
  int photoCalls = 0;
  String? lastName;
  String? lastEmail;
  String? lastPhoneNumber;
  String? lastPhotoPath;

  @override
  Future<UserModel> updateProfile({required String name, required String email, String? phoneNumber}) async {
    updateCalls++;
    lastName = name;
    lastEmail = email;
    lastPhoneNumber = phoneNumber;
    if (updateError != null) throw updateError!;
    return updateResult!;
  }

  @override
  Future<UserModel> updatePhoto(String filePath) async {
    photoCalls++;
    lastPhotoPath = filePath;
    if (photoError != null) throw photoError!;
    return photoResult!;
  }
}

AuthProvider _authProvider() => AuthProvider(authRepository: AuthRepository(apiClient: ApiClient(), tokenStorage: TokenStorage()));

void main() {
  group('initial state', () {
    test('seeds fields from the constructor args', () {
      final provider = EditPersonalInfoProvider(
        _FakeProfileRepository(),
        _authProvider(),
        initialName: 'Nurul Aisyah binti Ahmad',
        initialEmail: 'customer@ecoxchange.com',
        initialPhoneNumber: '+60123456780',
        initialPhotoUrl: 'https://ecoxchange.test/storage/avatars/old.jpg',
      );

      expect(provider.name, 'Nurul Aisyah binti Ahmad');
      expect(provider.email, 'customer@ecoxchange.com');
      expect(provider.phoneNumber, '+60123456780');
      expect(provider.photoUrl, 'https://ecoxchange.test/storage/avatars/old.jpg');
    });

    test('a null initial phone becomes an empty editable string', () {
      final provider = EditPersonalInfoProvider(
        _FakeProfileRepository(),
        _authProvider(),
        initialName: 'A',
        initialEmail: 'a@example.com',
        initialPhoneNumber: null,
        initialPhotoUrl: null,
      );

      expect(provider.phoneNumber, '');
    });
  });

  group('field editing', () {
    test('setName/setEmail/setPhoneNumber update the local state', () {
      final provider = EditPersonalInfoProvider(
        _FakeProfileRepository(),
        _authProvider(),
        initialName: 'Old',
        initialEmail: 'old@example.com',
        initialPhoneNumber: '1',
        initialPhotoUrl: null,
      );

      provider.setName('New Name');
      provider.setEmail('new@example.com');
      provider.setPhoneNumber('+60199999999');

      expect(provider.name, 'New Name');
      expect(provider.email, 'new@example.com');
      expect(provider.phoneNumber, '+60199999999');
    });
  });

  group('local validation', () {
    test('an empty name is rejected before any network call', () async {
      final repo = _FakeProfileRepository();
      final provider = EditPersonalInfoProvider(repo, _authProvider(), initialName: '  ', initialEmail: 'a@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      final result = await provider.save();

      expect(result, isNull);
      expect(provider.saveError, isNotNull);
      expect(repo.updateCalls, 0);
    });

    test('a malformed email is rejected before any network call', () async {
      final repo = _FakeProfileRepository();
      final provider = EditPersonalInfoProvider(repo, _authProvider(), initialName: 'A', initialEmail: 'not-an-email', initialPhoneNumber: null, initialPhotoUrl: null);

      final result = await provider.save();

      expect(result, isNull);
      expect(provider.saveError, isNotNull);
      expect(repo.updateCalls, 0);
    });
  });

  group('save', () {
    test('a valid save calls the repository with trimmed values and updates AuthProvider', () async {
      final updated = _user(name: 'New Name', phoneNumber: '+60199999999');
      final repo = _FakeProfileRepository(updateResult: updated);
      final auth = _authProvider();
      final provider = EditPersonalInfoProvider(repo, auth, initialName: 'Old', initialEmail: 'old@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      provider.setName('  New Name  ');
      provider.setEmail(' new@example.com ');
      provider.setPhoneNumber(' +60199999999 ');

      final result = await provider.save();

      expect(result, same(updated));
      expect(repo.lastName, 'New Name');
      expect(repo.lastEmail, 'new@example.com');
      expect(repo.lastPhoneNumber, '+60199999999');
      expect(auth.user, same(updated));
      expect(provider.isSaving, isFalse);
      expect(provider.saveError, isNull);
    });

    test('an empty phone is sent as null, never an empty string', () async {
      final repo = _FakeProfileRepository(updateResult: _user());
      final provider = EditPersonalInfoProvider(repo, _authProvider(), initialName: 'A', initialEmail: 'a@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      provider.setPhoneNumber('   ');
      await provider.save();

      expect(repo.lastPhoneNumber, isNull);
    });

    test('a server validation failure (e.g. duplicate email) surfaces as saveError, never crashes', () async {
      const error = ValidationException('The email has already been taken.', {'email': ['The email has already been taken.']});
      final repo = _FakeProfileRepository(updateError: error);
      final auth = _authProvider();
      final provider = EditPersonalInfoProvider(repo, auth, initialName: 'A', initialEmail: 'taken@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      final result = await provider.save();

      expect(result, isNull);
      expect(provider.saveError, same(error));
      expect(auth.user, isNull); // never updated on failure
    });

    test('a double-tap while saving does not fire a second request', () async {
      final repo = _FakeProfileRepository(updateResult: _user());
      final provider = EditPersonalInfoProvider(repo, _authProvider(), initialName: 'A', initialEmail: 'a@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      final first = provider.save();
      final second = provider.save();

      await Future.wait([first, second]);
      expect(repo.updateCalls, 1);
    });
  });

  group('photo upload', () {
    test('a successful upload replaces photoUrl and updates AuthProvider', () async {
      final updated = _user(profilePhotoUrl: 'https://ecoxchange.test/storage/avatars/new.jpg');
      final repo = _FakeProfileRepository(photoResult: updated);
      final auth = _authProvider();
      final provider = EditPersonalInfoProvider(repo, auth, initialName: 'A', initialEmail: 'a@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      await provider.debugUploadPhotoAt('/tmp/fake.jpg');

      expect(repo.photoCalls, 1);
      expect(repo.lastPhotoPath, '/tmp/fake.jpg');
      expect(provider.photoUrl, 'https://ecoxchange.test/storage/avatars/new.jpg');
      expect(provider.pickedImagePath, isNull); // cleared after upload completes
      expect(provider.isUploadingPhoto, isFalse);
      expect(auth.user, same(updated));
    });

    test('an upload failure keeps the previous photo and surfaces photoError', () async {
      const error = ServerException('Something went wrong. Please try again.');
      final repo = _FakeProfileRepository(photoError: error);
      final provider = EditPersonalInfoProvider(
        repo,
        _authProvider(),
        initialName: 'A',
        initialEmail: 'a@example.com',
        initialPhoneNumber: null,
        initialPhotoUrl: 'https://ecoxchange.test/storage/avatars/old.jpg',
      );

      await provider.debugUploadPhotoAt('/tmp/bad.jpg');

      expect(provider.photoError, same(error));
      expect(provider.photoUrl, 'https://ecoxchange.test/storage/avatars/old.jpg'); // unchanged
      expect(provider.isUploadingPhoto, isFalse);
    });

    test('while uploading, isUploadingPhoto is true and a local preview path is set', () async {
      final repo = _FakeProfileRepository(photoResult: _user());
      final provider = EditPersonalInfoProvider(repo, _authProvider(), initialName: 'A', initialEmail: 'a@example.com', initialPhoneNumber: null, initialPhotoUrl: null);

      final future = provider.debugUploadPhotoAt('/tmp/fake.jpg');
      expect(provider.isUploadingPhoto, isTrue);
      expect(provider.pickedImagePath, '/tmp/fake.jpg');

      await future;
      expect(provider.isUploadingPhoto, isFalse);
    });
  });
}
