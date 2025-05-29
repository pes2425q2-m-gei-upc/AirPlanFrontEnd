import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rive/rive.dart';
import 'package:airplan/rive_controller.dart';

// Solo mockea Artboard - no necesitas mockear los controladores
@GenerateMocks([Artboard])
import 'rive_controller_test.mocks.dart';

void main() {
  late RiveAnimationControllerHelper riveHelper;
  late MockArtboard mockArtboard;

  setUp(() {
    riveHelper = RiveAnimationControllerHelper();
    mockArtboard = MockArtboard();

    // Setup stub for the addController method which will be called
    // Use true for successful addition of controllers
    when(mockArtboard.addController(any)).thenReturn(true);

    // Setup stub for the removeController method which is also called
    // Use true for successful removal of controllers
    when(mockArtboard.removeController(any)).thenReturn(true);
  });

  group('RiveAnimationControllerHelper Tests', () {
    test('singleton pattern works correctly', () {
      final helper1 = RiveAnimationControllerHelper();
      final helper2 = RiveAnimationControllerHelper();

      // Verify both instances are the same (singleton pattern)
      expect(identical(helper1, helper2), isTrue);
    });

    test('initialize method sets up controllers correctly', () {
      // Act
      riveHelper.initialize(mockArtboard);

      // Assert
      expect(riveHelper.riveArtboard, equals(mockArtboard));
      // Verify addController was called at least once during initialization
      verify(mockArtboard.addController(any)).called(1);
    });

    test('setHandsUp updates state correctly', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // Clear interactions from the initialize method
      clearInteractions(mockArtboard);
      expect(riveHelper.isHandsUp, isFalse);

      // Act
      riveHelper.setHandsUp();

      // Assert
      expect(riveHelper.isHandsUp, isTrue);
      // Verify addController was called to add the hands up animation
      verify(mockArtboard.addController(any)).called(1);
    });

    test('setHandsDown updates state correctly', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // Clear interactions from the initialize method
      clearInteractions(mockArtboard);
      riveHelper.isHandsUp = true;

      // Act
      riveHelper.setHandsDown();

      // Assert
      expect(riveHelper.isHandsUp, isFalse);
      // Verify addController was called to add the hands down animation
      verify(mockArtboard.addController(any)).called(1);
    });

    test('setLookRight updates state correctly', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // Clear interactions from the initialize method
      clearInteractions(mockArtboard);
      expect(riveHelper.isLookingRight, isFalse);
      expect(riveHelper.isLookingLeft, isFalse);

      // Act
      riveHelper.setLookRight();

      // Assert
      expect(riveHelper.isLookingRight, isTrue);
      expect(riveHelper.isLookingLeft, isFalse);
      verify(mockArtboard.addController(any)).called(1);
    });

    test('setLookLeft updates state correctly', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // Clear interactions from the initialize method
      clearInteractions(mockArtboard);
      expect(riveHelper.isLookingLeft, isFalse);

      // Reset any potential state
      riveHelper.isLookingRight = false;

      // Act
      riveHelper.setLookLeft();

      // Assert
      expect(riveHelper.isLookingLeft, isTrue);
      expect(riveHelper.isLookingRight, isFalse);
      verify(mockArtboard.addController(any)).called(1);
    });

    test('setIdle resets all states', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // Clear interactions from the initialize method
      clearInteractions(mockArtboard);
      riveHelper.isLookingRight = true;
      riveHelper.isLookingLeft = true;
      riveHelper.isHandsUp = true;

      // Act
      riveHelper.setIdle();

      // Assert
      expect(riveHelper.isLookingRight, isFalse);
      expect(riveHelper.isLookingLeft, isFalse);
      expect(riveHelper.isHandsUp, isFalse);
      verify(mockArtboard.addController(any)).called(1);
    });

    test('resetState resets all state flags', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // For this test we don't need to verify controller interactions
      riveHelper.isLookingRight = true;
      riveHelper.isLookingLeft = true;
      riveHelper.isHandsUp = true;

      // Act
      riveHelper.resetState();

      // Assert
      expect(riveHelper.isLookingRight, isFalse);
      expect(riveHelper.isLookingLeft, isFalse);
      expect(riveHelper.isHandsUp, isFalse);
    });

    test('convenience methods call appropriate state methods', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      // Clear interactions from the initialize method
      clearInteractions(mockArtboard);

      // Act & Assert - we test that these methods internally call to the right functions
      riveHelper.addHandsUpController();
      expect(riveHelper.isHandsUp, isTrue);
      verify(mockArtboard.addController(any)).called(1);

      clearInteractions(mockArtboard);
      riveHelper.resetState();
      riveHelper.addDownLeftController();
      expect(riveHelper.isLookingLeft, isTrue);
      verify(mockArtboard.addController(any)).called(1);

      clearInteractions(mockArtboard);
      riveHelper.resetState();
      riveHelper.addDownRightController();
      expect(riveHelper.isLookingRight, isTrue);
      verify(mockArtboard.addController(any)).called(1);
    });

    test('removeAllControllers calls removeController on all animations', () {
      // Arrange
      riveHelper.initialize(mockArtboard);
      clearInteractions(mockArtboard);

      // Act
      riveHelper.removeAllControllers();

      // Assert - there are 7 controllers to remove
      verify(mockArtboard.removeController(any)).called(7);
    });
  });
}