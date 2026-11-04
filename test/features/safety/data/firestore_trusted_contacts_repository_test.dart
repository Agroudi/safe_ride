import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/core/session/session_reader.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/firestore_trusted_contacts_repository.dart';

class _Session implements SessionReader {
  _Session(this.uid);

  String? uid;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  Future<SessionUser?> signedInUser() async =>
      uid == null ? null : SessionUser(id: uid!, fullName: 'Sara');
}

Matcher _fails(ContactFailureCode code) => throwsA(
  isA<ContactFailure>().having((ContactFailure f) => f.code, 'code', code),
);

void main() {
  late FakeFirebaseFirestore db;
  late _Session session;
  late FirestoreTrustedContactsRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    session = _Session('sara');
    repository = FirestoreTrustedContactsRepository(db, session);
  });

  test('a contact is stored tidied, with its digits, listed by name', () async {
    final TrustedContactModel mona = await repository.add(
      fullName: '  Mona   Saleh ',
      phone: ' +966 55 111 2222 ',
      relationship: ' ',
    );
    await repository.add(fullName: 'ali', phone: '+966500000000');

    expect(mona.fullName, 'Mona Saleh');
    expect(mona.relationship, isNull);
    final Map<String, dynamic> stored =
        (await db.doc('users/sara/contacts/${mona.id}').get()).data()!;
    expect(stored['phoneDigits'], '966551112222');
    expect(
      stored.keys,
      unorderedEquals(<String>[
        'fullName',
        'phone',
        'phoneDigits',
        'relationship',
        'createdAt',
        'updatedAt',
      ]),
    );
    expect(
      (await repository.contacts()).map((TrustedContactModel c) => c.fullName),
      <String>['ali', 'Mona Saleh'],
    );
  });

  test('one number, however it is written, is one contact', () async {
    final TrustedContactModel mona = await repository.add(
      fullName: 'Mona',
      phone: '+966 55-111-2222',
    );
    expect(
      repository.add(fullName: 'Again', phone: '+966551112222'),
      _fails(ContactFailureCode.duplicatePhone),
    );
    // Its own number is not a duplicate of itself.
    await repository.update(
      mona.id,
      fullName: 'Mona S',
      phone: '+966551112222',
    );
  });

  test('the list holds 20', () async {
    for (int i = 0; i < FirestoreTrustedContactsRepository.maxContacts; i++) {
      await repository.add(
        fullName: 'Person $i',
        phone: '+96650000${1000 + i}',
      );
    }
    expect(
      repository.add(fullName: 'One more', phone: '+966511111111'),
      _fails(ContactFailureCode.full),
    );
  });

  test('edit and delete change only that contact', () async {
    final TrustedContactModel a = await repository.add(
      fullName: 'Ahmed',
      phone: '+966501111111',
    );
    final TrustedContactModel b = await repository.add(
      fullName: 'Basma',
      phone: '+966502222222',
    );
    await repository.update(a.id, fullName: 'Ahmed A', phone: a.phone);
    await repository.delete(b.id);

    final List<TrustedContactModel> left = await repository.contacts();
    expect(left.single.fullName, 'Ahmed A');
    expect(repository.delete(b.id), _fails(ContactFailureCode.notFound));
  });

  test('each account has its own list; signed out there is none', () async {
    final TrustedContactModel mona = await repository.add(
      fullName: 'Mona',
      phone: '+966551112222',
    );

    session.uid = 'omar';
    expect(await repository.contacts(), isEmpty);
    expect(await repository.contact(mona.id), isNull);
    // Omar may keep the same number: lists are per account.
    await repository.add(fullName: 'Mona', phone: '+966551112222');

    session.uid = null;
    expect(repository.contacts(), _fails(ContactFailureCode.signedOut));
  });
}
