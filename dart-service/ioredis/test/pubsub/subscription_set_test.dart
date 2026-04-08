import 'package:test/test.dart';
import 'package:ioredis/src/pubsub/subscription_set.dart';

void main() {
  group('SubscriptionSet', () {
    late SubscriptionSet set;

    setUp(() {
      set = SubscriptionSet();
    });

    test('starts empty', () {
      expect(set.isEmpty, isTrue);
    });

    test('add and retrieve channels', () {
      set.add('subscribe', 'news');
      set.add('subscribe', 'events');
      expect(set.channels('subscribe'), equals({'news', 'events'}));
      expect(set.isEmpty, isFalse);
    });

    test('remove channel', () {
      set.add('subscribe', 'news');
      set.remove('unsubscribe', 'news');
      expect(set.channels('subscribe'), isEmpty);
      expect(set.isEmpty, isTrue);
    });

    test('supports psubscribe', () {
      set.add('psubscribe', 'news.*');
      expect(set.channels('psubscribe'), equals({'news.*'}));
    });

    test('remove via punsubscribe', () {
      set.add('psubscribe', 'news.*');
      set.remove('punsubscribe', 'news.*');
      expect(set.channels('psubscribe'), isEmpty);
    });

    test('supports ssubscribe', () {
      set.add('ssubscribe', 'channel');
      expect(set.channels('ssubscribe'), equals({'channel'}));
    });

    test('isEmpty checks all types', () {
      set.add('subscribe', 'a');
      expect(set.isEmpty, isFalse);
      set.remove('unsubscribe', 'a');
      expect(set.isEmpty, isTrue);
    });

    test('clear removes everything', () {
      set.add('subscribe', 'a');
      set.add('psubscribe', 'b.*');
      set.add('ssubscribe', 'c');
      set.clear();
      expect(set.isEmpty, isTrue);
    });
  });
}
