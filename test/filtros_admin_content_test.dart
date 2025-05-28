import 'package:flutter_test/flutter_test.dart';
import 'package:airplan/filtros_admin_content.dart';

void main() {
  group('StringExtension', () {
    test('capitalizeFirstofEach on simple strings', () {
      expect('TOXICITY'.capitalizeFirstofEach, 'Toxicity');
      expect('SEVERE_TOXICITY'.capitalizeFirstofEach, 'Severe Toxicity');
      expect(''.capitalizeFirstofEach, '');
      expect(
        'multiple_words_here'.capitalizeFirstofEach,
        'Multiple Words Here',
      );
    });

    test('capitalizeFirstofEach handles already formatted strings', () {
      expect('Already Formatted'.capitalizeFirstofEach, 'Already Formatted');
    });
  });

  group('AttributeSettingUIModel', () {
    test('default values are set correctly', () {
      final model = AttributeSettingUIModel(name: 'TEST');
      expect(model.name, 'TEST');
      expect(model.isEnabled, false);
      expect(model.threshold, 0.7);
      expect(model.thresholdController.text, '0.7');
    });

    test('thresholdController text can be updated and parsed', () {
      final model = AttributeSettingUIModel(name: 'TEST');
      model.thresholdController.text = '0.42';
      final parsed = double.tryParse(model.thresholdController.text);
      expect(parsed, isNotNull);
      expect(parsed, 0.42);
      model.threshold = parsed!;
      expect(model.threshold, 0.42);
    });

    test('dispose does not throw and cleans up controller', () {
      final model = AttributeSettingUIModel(name: 'TEST');
      expect(() => model.dispose(), returnsNormally);
    });
  });
}
