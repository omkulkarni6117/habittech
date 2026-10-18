import 'package:flutter_test/flutter_test.dart';
import 'package:habittech/core/date_utils.dart';
import 'package:habittech/core/time_utils.dart';

void main() {
  group('month lengths and leap years', () {
    test('February in leap and non-leap years', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2025, 2), 28);
      expect(daysInMonth(2000, 2), 29); // divisible by 400
      expect(daysInMonth(1900, 2), 28); // divisible by 100, not 400
    });

    test('all other months', () {
      const expected = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
      for (var m = 1; m <= 12; m++) {
        expect(daysInMonth(2026, m), expected[m - 1], reason: 'month $m');
      }
    });

    test('isLeapYear', () {
      expect(isLeapYear(2024), isTrue);
      expect(isLeapYear(2026), isFalse);
      expect(isLeapYear(2100), isFalse);
      expect(isLeapYear(2400), isTrue);
    });
  });

  group('date keys', () {
    test('format and parse round trip', () {
      expect(dateKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
      expect(parseDateKey('2026-03-05'), DateTime(2026, 3, 5));
    });

    test('rejects malformed and impossible dates', () {
      expect(tryParseDateKey('2026-02-30'), isNull);
      expect(tryParseDateKey('2026-13-01'), isNull);
      expect(tryParseDateKey('26-1-1'), isNull);
      expect(tryParseDateKey('2026-02-29'), isNull); // not a leap year
      expect(tryParseDateKey('2024-02-29'), DateTime(2024, 2, 29));
      expect(() => parseDateKey('nope'), throwsFormatException);
    });
  });

  group('day arithmetic', () {
    test('addDays crosses month and year boundaries', () {
      expect(addDays(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
      expect(addDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
      expect(addDays(DateTime(2024, 2, 28), 1), DateTime(2024, 2, 29));
      expect(addDays(DateTime(2025, 3, 1), -1), DateTime(2025, 2, 28));
    });

    test('daysBetween counts calendar days', () {
      expect(daysBetween(DateTime(2026, 10, 1), DateTime(2026, 10, 14)), 13);
      expect(daysBetween(DateTime(2026, 10, 14), DateTime(2026, 10, 1)), -13);
      expect(daysBetween(DateTime(2023, 12, 31), DateTime(2024, 12, 31)), 366);
    });

    test('startOfWeek honours the week-start setting', () {
      final wed = DateTime(2026, 10, 14);
      expect(startOfWeek(wed, 1), DateTime(2026, 10, 12)); // Monday
      expect(startOfWeek(wed, 7), DateTime(2026, 10, 11)); // Sunday
      expect(startOfWeek(wed, 6), DateTime(2026, 10, 10)); // Saturday
      expect(startOfWeek(DateTime(2026, 10, 12), 1), DateTime(2026, 10, 12));
    });

    test('weekdayOrder', () {
      expect(weekdayOrder(1), [1, 2, 3, 4, 5, 6, 7]);
      expect(weekdayOrder(7), [7, 1, 2, 3, 4, 5, 6]);
    });
  });

  group('sleep duration', () {
    test('same-day sleep', () {
      expect(sleepDurationMinutes('01:00', '07:30'), 390);
    });

    test('overnight sleep crosses midnight', () {
      expect(sleepDurationMinutes('23:00', '07:00'), 480);
      expect(sleepDurationMinutes('22:30', '06:15'), 465);
      expect(sleepDurationMinutes('23:59', '00:01'), 2);
    });

    test('identical times and bad input give zero', () {
      expect(sleepDurationMinutes('07:00', '07:00'), 0);
      expect(sleepDurationMinutes('7am', '07:00'), 0);
      expect(sleepDurationMinutes('25:00', '07:00'), 0);
    });

    test('time parsing and formatting', () {
      expect(parseHm('00:00'), 0);
      expect(parseHm('23:59'), 1439);
      expect(parseHm('24:00'), isNull);
      expect(parseHm('9:00'), isNull);
      expect(hmFromMinutes(-60), '23:00'); // wraps backwards over midnight
      expect(hmFromMinutes(1500), '01:00');
      expect(format12h('00:05'), '12:05 AM');
      expect(format12h('12:00'), '12:00 PM');
      expect(format12h('23:30'), '11:30 PM');
    });

    test('formatDuration', () {
      expect(formatDuration(480), '8h');
      expect(formatDuration(450), '7h 30m');
      expect(formatDuration(45), '45m');
    });
  });
}
