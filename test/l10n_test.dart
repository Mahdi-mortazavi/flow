import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taknoghte/core/l10n.dart';
import 'package:taknoghte/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('L10n and AppLanguage Tests', () {
    test('AppLanguage direction and codes match specification', () {
      expect(AppLanguage.fa.code, 'fa');
      expect(AppLanguage.fa.direction, TextDirection.rtl);
      expect(AppLanguage.en.code, 'en');
      expect(AppLanguage.en.direction, TextDirection.ltr);

      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('fa'), AppLanguage.fa);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.fa);
    });

    test(
      'L10n translations reflect behavioral science & psychological tone',
      () {
        expect(L10n.theBoulder(AppLanguage.fa), 'تخته‌سنگ');
        expect(L10n.theBoulder(AppLanguage.en), 'The Boulder');

        expect(L10n.brainVaultTitle(AppLanguage.fa), 'مخزن ذهن');
        expect(L10n.brainVaultTitle(AppLanguage.en), 'Brain Vault');

        expect(L10n.statsMirrorTitle(AppLanguage.fa), 'آینه');
        expect(L10n.statsMirrorTitle(AppLanguage.en), 'Stats Mirror');

        expect(L10n.prediction(AppLanguage.fa), 'پیش‌بینی');
        expect(L10n.prediction(AppLanguage.en), 'Prediction');

        expect(L10n.optimismGap(AppLanguage.fa), 'شکاف خوش‌بینی');
        expect(L10n.optimismGap(AppLanguage.en), 'Optimism Gap');

        expect(L10n.appLanguage(AppLanguage.fa), 'زبان برنامه / App Language');
        expect(L10n.appLanguage(AppLanguage.en), 'App Language / زبان برنامه');
      },
    );

    test(
      'L10n digit and date formatting helpers work correctly for fa and en',
      () {
        expect(L10n.fmtNum(123, AppLanguage.fa), '۱۲۳');
        expect(L10n.fmtNum(123, AppLanguage.en), '123');

        expect(L10n.fmtClock(330, AppLanguage.fa), '۰۵:۳۰');
        expect(L10n.fmtClock(330, AppLanguage.en), '05:30');

        expect(L10n.fmtDayLabel('2026-07-16', AppLanguage.en), 'Jul 16');
        expect(L10n.fmtTodayLabel(AppLanguage.en), isNotEmpty);
      },
    );

    test(
      'AppLanguageController toggles and persists preference via SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(appLanguageProvider), AppLanguage.fa);

        await container
            .read(appLanguageProvider.notifier)
            .setLanguage(AppLanguage.en);
        expect(container.read(appLanguageProvider), AppLanguage.en);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(AppLanguageController.prefKey), 'en');

        await container.read(appLanguageProvider.notifier).toggleLanguage();
        expect(container.read(appLanguageProvider), AppLanguage.fa);
        expect(prefs.getString(AppLanguageController.prefKey), 'fa');
      },
    );
  });
}
