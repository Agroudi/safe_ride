import 'package:flutter_test/flutter_test.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/data/models/trusted_contact_model.dart';
import 'package:safe_ride/features/safety/data/repository/trusted_contacts_repository.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_form_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contact_form_state.dart';

final TrustedContactModel _mona = TrustedContactModel(
  id: 'c1',
  fullName: 'Mona Saleh',
  phone: '+966551112222',
  createdAt: DateTime.utc(2026),
);

/// Reads fail while [unreadable] is set; every write is recorded.
class _Repository extends Fake implements TrustedContactsRepository {
  bool unreadable = false;
  final List<String> writes = <String>[];

  @override
  Future<TrustedContactModel?> contact(String id) async {
    if (unreadable) throw const ContactFailure(ContactFailureCode.storage);
    return id == _mona.id ? _mona : null;
  }

  @override
  Future<TrustedContactModel> add({
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    writes.add('add $fullName');
    return _mona;
  }

  @override
  Future<TrustedContactModel> update(
    String id, {
    required String fullName,
    required String phone,
    String? relationship,
  }) async {
    writes.add('update $id');
    return _mona;
  }

  @override
  Future<void> delete(String id) async => writes.add('delete $id');
}

/// An edit whose contact could not be read must never turn into an add or
/// report a delete that did not happen.
void main() {
  test('an unreadable contact can be neither saved nor deleted', () async {
    final _Repository repository = _Repository()..unreadable = true;
    final ContactFormCubit cubit = ContactFormCubit(repository);

    await cubit.load(_mona.id);
    expect(cubit.state, const ContactFormUnreadable());

    await cubit.save(fullName: 'Mona Saleh', phone: '+966551112222');
    await cubit.delete();
    expect(repository.writes, isEmpty);
    expect(cubit.state, const ContactFormUnreadable());
    await cubit.close();
  });

  test('a retry that reads it lets the edit go through', () async {
    final _Repository repository = _Repository()..unreadable = true;
    final ContactFormCubit cubit = ContactFormCubit(repository);
    await cubit.load(_mona.id);

    repository.unreadable = false;
    await cubit.retry();
    expect(cubit.state, ContactFormReady(contact: _mona));

    await cubit.save(fullName: 'Mona', phone: '+966551112222');
    expect(repository.writes, <String>['update c1']);
    expect(cubit.state, const ContactFormSaved());
    await cubit.close();
  });

  test('adding saves a new contact', () async {
    final _Repository repository = _Repository();
    final ContactFormCubit cubit = ContactFormCubit(repository);

    await cubit.save(fullName: 'Omar', phone: '+966500000000');
    expect(repository.writes, <String>['add Omar']);
    await cubit.close();
  });
}
