import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taknoghte/core/l10n.dart';
import 'package:taknoghte/core/theme.dart';
import 'package:taknoghte/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAccent and Theme Tests', () {
    test('AppAccent values, codes and colors match specification', () {
      expect(AppAccent.ember.code, 'ember');
      expect(AppAccent.ember.color, const Color(0xFFEFA55C));

      expect(AppAccent.pine.code, 'pine');
      expect(AppAccent.pine.color, const Color(0xFF4EAF7B));

      expect(AppAccent.indigo.code, 'indigo');
      expect(AppAccent.indigo.color, const Color(0xFF5486EB));

      expect(AppAccent.mulberry.code, 'mulberry');
      expect(AppAccent.mulberry.color, const Color(0xFFD65B6E));

      expect(AppAccent.slate.code, 'slate');
      expect(AppAccent.slate.color, const Color(0xFFA2ADC0));

      expect(AppAccent.iris.code, 'iris');
      expect(AppAccent.iris.color, const Color(0xFF9F7AEA));

      expect(AppAccent.fromCode('pine'), AppAccent.pine);
      expect(AppAccent.fromCode('unknown'), AppAccent.ember);
    });

    test(
      'AppAccent localized labels return correct Persian and English strings',
      () {
        expect(AppAccent.ember.label(AppLanguage.fa), 'کهربایی');
        expect(AppAccent.ember.label(AppLanguage.en), 'Ember');

        expect(AppAccent.pine.label(AppLanguage.fa), 'سوزن کاج');
        expect(AppAccent.pine.label(AppLanguage.en), 'Alpine Pine');

        expect(AppAccent.indigo.label(AppLanguage.fa), 'نیلی ژرف');
        expect(AppAccent.indigo.label(AppLanguage.en), 'Abyssal Indigo');

        expect(AppAccent.mulberry.label(AppLanguage.fa), 'شاتوتی');
        expect(AppAccent.mulberry.label(AppLanguage.en), 'Smoked Mulberry');

        expect(AppAccent.slate.label(AppLanguage.fa), 'گرانیت مهآلود');
        expect(AppAccent.slate.label(AppLanguage.en), 'Mist Slate');

        expect(AppAccent.iris.label(AppLanguage.fa), 'شفق شبانه');
        expect(AppAccent.iris.label(AppLanguage.en), 'Night Iris');
      },
    );

    test(
      'AppAccentController updates Tone accent and persists via SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(accentProvider), AppAccent.ember);
        expect(Tone.ember, AppAccent.ember.color);

        await container.read(accentProvider.notifier).setAccent(AppAccent.pine);
        expect(container.read(accentProvider), AppAccent.pine);
        expect(Tone.ember, AppAccent.pine.color);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AppAccentController.prefKey), 'pine');
      },
    );
  });
}
