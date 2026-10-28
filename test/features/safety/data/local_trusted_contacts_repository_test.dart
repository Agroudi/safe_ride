import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/local_trusted_contacts_repository.dart';

class _Session implements SessionReader {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  SessionUser? user = const SessionUser(
    id: 'sara@example.com',
    fullName: 'Sara',
  );

  @override
  Future<SessionUser?> signedInUser() async => user;
}

Matcher _fails(ContactFailureCode code) => throwsA(
  isA<ContactFailure>().having((ContactFailure f) => f.code, 'code', code),
);

void main() {
  late _Session session;
  late LocalTrustedContactsRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    session = _Session();
    repository = LocalTrustedContactsRepository(
      const FlutterSecureStorage(),
      session,
    );
  });

  test('contacts are saved tidied and listed by name', () async {
    await repository.add(fullName: '  Omar   Ali ', phone: ' 0501234567 ');
    await repository.add(
      fullName: 'Lina',
      phone: '+966 55 000 1111',
      relationship: ' Sister ',
    );
    await repository.add(
      fullName: 'mona',
      phone: '0559998888',
      relationship: ' ',
    );

    final List<TrustedContactModel> all = await repository.contacts();
    expect(all.map((TrustedContactModel c) => c.fullName), <String>[
      'Lina',
      'mona',
      'Omar Ali',
    ]);
    expect(all.first.relationship, 'Sister');
    expect(all[1].relationship, isNull);
    expect(all.last.phone, '0501234567');
  });

  test('one number, however it is written, is one contact', () async {
    await repository.add(fullName: 'Lina', phone: '+966 55 000 1111');
    expect(
      repository.add(fullName: 'Other', phone: '+966-55-000-1111'),
      _fails(ContactFailureCode.duplicatePhone),
    );
  });

  test(
    'edit keeps the contact; a number taken by another is refused',
    () async {
      final TrustedContactModel lina = await repository.add(
        fullName: 'Lina',
        phone: '0550001111',
      );
      await repository.add(fullName: 'Omar', phone: '0501234567');

      final TrustedContactModel edited = await repository.update(
        lina.id,
        fullName: 'Lina Saad',
        phone: '055 000 1111',
        relationship: 'Sister',
      );
      expect(edited.id, lina.id);
      expect(edited.fullName, 'Lina Saad');
      expect(edited.relationship, 'Sister');

      expect(
        repository.update(lina.id, fullName: 'Lina', phone: '0501234567'),
        _fails(ContactFailureCode.duplicatePhone),
      );
      expect(
        repository.update('nope', fullName: 'X', phone: '0500000000'),
        _fails(ContactFailureCode.notFound),
      );
    },
  );

  test('delete removes one contact, and only that one', () async {
    final TrustedContactModel a = await repository.add(
      fullName: 'A',
      phone: '0500000001',
    );
    await repository.add(fullName: 'B', phone: '0500000002');

    await repository.delete(a.id);
    expect((await repository.contacts()).single.fullName, 'B');
    expect(repository.delete(a.id), _fails(ContactFailureCode.notFound));
  });

  test('each account has its own list; signed out there is none', () async {
    await repository.add(fullName: 'Lina', phone: '0550001111');
    session.user = const SessionUser(id: 'omar@example.com', fullName: 'Omar');
    expect(await repository.contacts(), isEmpty);

    session.user = null;
    expect(repository.contacts(), _fails(ContactFailureCode.signedOut));
  });

  test(
    'the list holds at most ${LocalTrustedContactsRepository.maxContacts}',
    () async {
      for (int i = 0; i < LocalTrustedContactsRepository.maxContacts; i++) {
        await repository.add(
          fullName: 'C$i',
          phone: '05000000${i.toString().padLeft(2, '0')}',
        );
      }
      expect(
        repository.add(fullName: 'One more', phone: '0599999999'),
        _fails(ContactFailureCode.full),
      );
    },
  );

  test('a corrupt store is a storage failure, never a crash', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      LocalTrustedContactsRepository.keyFor('sara@example.com'): '{broken',
    });
    expect(repository.contacts(), _fails(ContactFailureCode.storage));
  });
}
