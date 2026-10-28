import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';

/// One notification at a time, newest wins, and the same message never
/// stacks.
void main() {
  const AppNotification noAccount = AppNotification.error(
    title: 'Something went wrong',
    message: 'No account exists with this email address.',
  );
  const AppNotification created = AppNotification.success(
    title: 'Account created',
  );

  test('severity sets how long it stays', () {
    expect(noAccount.duration, AppDurations.noticeLong);
    expect(
      const AppNotification.warning(title: 'w').duration,
      AppDurations.noticeLong,
    );
    expect(created.duration, AppDurations.noticeShort);
    expect(
      const AppNotification.info(title: 'i').duration,
      AppDurations.noticeShort,
    );
    expect(const AppNotification.offline(title: 'o').duration, isNull);
  });

  test('a new message replaces the one on screen', () {
    final AppNotifier notifier = AppNotifier()..show(noAccount);
    notifier.show(created);
    expect(notifier.current, created);
  });

  test('the same message again refreshes instead of stacking', () {
    final AppNotifier notifier = AppNotifier()..show(noAccount);
    final AppNotification first = notifier.current!;
    final int generation = notifier.generation;

    notifier.show(
      const AppNotification.error(
        title: 'Something went wrong',
        message: 'No account exists with this email address.',
      ),
    );

    expect(identical(notifier.current, first), isTrue);
    expect(notifier.generation, greaterThan(generation));
  });

  test('dismiss by id leaves someone else\'s message alone', () {
    final AppNotifier notifier = AppNotifier()..show(created);

    notifier.dismiss(id: noAccount.id);
    expect(notifier.current, created);

    notifier.dismiss(id: created.id);
    expect(notifier.current, isNull);
  });

  test('a one-line notice has its own id', () {
    expect(
      const AppNotification.info(title: 'a').id,
      isNot(const AppNotification.info(title: 'a', message: 'b').id),
    );
  });
}
