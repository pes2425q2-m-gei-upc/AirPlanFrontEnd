import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/services/auth_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([FirebaseAuth, UserCredential, User])
void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late AuthService authService;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    authService = AuthService(firebaseAuth: mockFirebaseAuth);
    mockUser = MockUser();
    when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
  });

  group('AuthService', () {
    test('getCurrentUser returns current Firebase user', () {
      final result = authService.getCurrentUser();
      expect(result, equals(mockUser));
      verify(mockFirebaseAuth.currentUser).called(1);
    });

    test('getCurrentUserId returns current Firebase user uid', () {
      when(mockUser.uid).thenReturn('test-uid');
      final result = authService.getCurrentUserId();
      expect(result, equals('test-uid'));
      verify(mockFirebaseAuth.currentUser).called(1);
      verify(mockUser.uid).called(1);
    });

    test('getCurrentUsername returns current Firebase user displayName', () {
      when(mockUser.displayName).thenReturn('testUser');
      final result = authService.getCurrentUsername();
      expect(result, equals('testUser'));
      verify(mockFirebaseAuth.currentUser).called(1);
      verify(mockUser.displayName).called(1);
    });

    test('isAuthenticated returns true when user is logged in', () {
      final result = authService.isAuthenticated();
      expect(result, isTrue);
      verify(mockFirebaseAuth.currentUser).called(1);
    });

    test('isAuthenticated returns false when user is not logged in', () {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      final result = authService.isAuthenticated();
      expect(result, isFalse);
      verify(mockFirebaseAuth.currentUser).called(1);
    });

    test('signOut calls Firebase signOut', () async {
      await authService.signOut();
      verify(mockFirebaseAuth.signOut()).called(1);
    });

    test(
      'signInWithEmailAndPassword calls Firebase signInWithEmailAndPassword',
      () async {
        final mockCredential = MockUserCredential();
        when(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password',
          ),
        ).thenAnswer((_) async => mockCredential);

        final result = await authService.signInWithEmailAndPassword(
          'test@example.com',
          'password',
        );

        expect(result, equals(mockCredential));
        verify(
          mockFirebaseAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password',
          ),
        ).called(1);
      },
    );

    test(
      'createUserWithEmailAndPassword calls Firebase createUserWithEmailAndPassword',
      () async {
        final mockCredential = MockUserCredential();
        when(
          mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password',
          ),
        ).thenAnswer((_) async => mockCredential);

        final result = await authService.createUserWithEmailAndPassword(
          'test@example.com',
          'password',
        );

        expect(result, equals(mockCredential));
        verify(
          mockFirebaseAuth.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password',
          ),
        ).called(1);
      },
    );

    test(
      'signInWithCustomToken calls Firebase signInWithCustomToken',
      () async {
        final mockCredential = MockUserCredential();
        when(
          mockFirebaseAuth.signInWithCustomToken('token'),
        ).thenAnswer((_) async => mockCredential);

        final result = await authService.signInWithCustomToken('token');

        expect(result, equals(mockCredential));
        verify(mockFirebaseAuth.signInWithCustomToken('token')).called(1);
      },
    );

    test('updateDisplayName calls Firebase updateDisplayName', () async {
      await authService.updateDisplayName('newDisplayName');
      verify(mockUser.updateDisplayName('newDisplayName')).called(1);
    });

    test('updateDisplayName does nothing when user is null', () async {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.updateDisplayName('newDisplayName');
      verifyNever(mockUser.updateDisplayName(any));
    });

    test('resetPassword calls Firebase sendPasswordResetEmail', () async {
      await authService.resetPassword('test@example.com');
      verify(
        mockFirebaseAuth.sendPasswordResetEmail(email: 'test@example.com'),
      ).called(1);
    });

    // Test the newly added methods
    test(
      'sendEmailVerification calls Firebase sendEmailVerification',
      () async {
        await authService.sendEmailVerification();
        verify(mockUser.sendEmailVerification()).called(1);
      },
    );

    test('sendEmailVerification does nothing when user is null', () async {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.sendEmailVerification();
      verifyNever(mockUser.sendEmailVerification());
    });

    test('updatePhotoURL calls Firebase updatePhotoURL', () async {
      await authService.updatePhotoURL('https://example.com/photo.jpg');
      verify(
        mockUser.updatePhotoURL('https://example.com/photo.jpg'),
      ).called(1);
    });

    test('updatePhotoURL does nothing when user is null', () async {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.updatePhotoURL('https://example.com/photo.jpg');
      verifyNever(mockUser.updatePhotoURL(any));
    });

    test('updatePassword calls Firebase updatePassword', () async {
      await authService.updatePassword('newPassword');
      verify(mockUser.updatePassword('newPassword')).called(1);
    });

    test('updatePassword does nothing when user is null', () async {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.updatePassword('newPassword');
      verifyNever(mockUser.updatePassword(any));
    });

    test('reloadCurrentUser calls Firebase reload', () async {
      await authService.reloadCurrentUser();
      verify(mockUser.reload()).called(1);
    });

    test('reloadCurrentUser does nothing when user is null', () async {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.reloadCurrentUser();
      verifyNever(mockUser.reload());
    });

    test('deleteCurrentUser calls Firebase delete', () async {
      await authService.deleteCurrentUser();
      verify(mockUser.delete()).called(1);
    });

    test('deleteCurrentUser does nothing when user is null', () async {
      when(mockFirebaseAuth.currentUser).thenReturn(null);
      await authService.deleteCurrentUser();
      verifyNever(mockUser.delete());
    });
  });
}
