import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_confirm_dialog.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/data/models/contact_failure.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_form_cubit.dart';
import 'package:safe_ride/features/safety/logic/states/contact_form_state.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_fields.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_form_actions.dart';
import 'package:safe_ride/features/safety/presentation/widgets/safety_notices.dart';

/// Add a trusted contact ([id] null) or edit one — and delete it, after a
/// confirmation. A taken number shows under the phone field; what was typed
/// stays. A missing contact says so.
class ContactFormPage extends StatelessWidget {
  const ContactFormPage({this.id, super.key});

  final String? id;

  @override
  Widget build(BuildContext context) => BlocProvider<ContactFormCubit>(
    create: (_) {
      final ContactFormCubit cubit = sl<ContactFormCubit>();
      final String? editing = id;
      if (editing != null) cubit.load(editing);
      return cubit;
    },
    child: _ContactFormView(editing: id != null),
  );
}

class _ContactFormView extends StatefulWidget {
  const _ContactFormView({required this.editing});

  final bool editing;

  @override
  State<_ContactFormView> createState() => _ContactFormViewState();
}

class _ContactFormViewState extends State<_ContactFormView> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _relationship = TextEditingController();
  AutovalidateMode _mode = AutovalidateMode.disabled;
  String? _phoneError;
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, ContactFormState state) {
    switch (state) {
      case ContactFormReady(:final contact?) when !_filled:
        _filled = true;
        _name.text = contact.fullName;
        _phone.text = contact.phone;
        _relationship.text = contact.relationship ?? '';
      case ContactFormSaved():
        sl<AppNotifier>().show(
          SafetyNotices.contact(context, widget.editing ? 'updated' : 'added'),
        );
        context.pop();
      case ContactFormDeleted():
        sl<AppNotifier>().show(SafetyNotices.contact(context, 'deleted'));
        context.pop();
      case ContactFormFailed(code: ContactFailureCode.duplicatePhone):
        setState(
          () =>
              _phoneError = context.tr('safety.contacts.errors.duplicatePhone'),
        );
      case ContactFormFailed(:final ContactFailureCode code):
        sl<AppNotifier>().show(SafetyNotices.failure(context, code));
      default:
        break;
    }
  }

  void _clearPhoneError() {
    if (_phoneError != null) setState(() => _phoneError = null);
  }

  void _save() {
    FocusScope.of(context).unfocus();
    setState(() => _phoneError = null);
    if (!_form.currentState!.validate()) {
      setState(() => _mode = AutovalidateMode.onUserInteraction);
      return;
    }
    context.read<ContactFormCubit>().save(
      fullName: _name.text,
      phone: _phone.text,
      relationship: _relationship.text,
    );
  }

  Future<void> _delete() async {
    final ContactFormCubit form = context.read<ContactFormCubit>();
    final bool yes = await showAppConfirmDialog(
      context,
      title: context.tr('safety.contacts.confirmDelete.title'),
      message: context.tr(
        'safety.contacts.confirmDelete.message',
        namedArgs: <String, String>{'name': _name.text.trim()},
      ),
      confirmLabel: context.tr('safety.contacts.confirmDelete.confirm'),
      cancelLabel: context.tr('safety.contacts.confirmDelete.cancel'),
      destructive: true,
    );
    if (yes) await form.delete();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ContactFormCubit, ContactFormState>(
      listener: _onState,
      builder: (BuildContext context, ContactFormState state) {
        final bool busy = state is ContactFormBusy;
        return FormScaffold(
          formKey: _form,
          autovalidateMode: _mode,
          children: <Widget>[
            TitleBar(
              title: context.tr(
                widget.editing
                    ? 'safety.contacts.form.editTitle'
                    : 'safety.contacts.form.addTitle',
              ),
            ),
            Gap(24.fx),
            if (state is ContactFormLoading)
              const Center(child: CircularProgressIndicator())
            else if (state is ContactFormMissing)
              AppEmptyState(
                icon: Icons.person_off_rounded,
                title: context.tr('safety.contacts.errors.notFound'),
                body: context.tr('safety.contacts.notice'),
              )
            else ...<Widget>[
              ContactFields(
                name: _name,
                phone: _phone,
                relationship: _relationship,
                enabled: !busy,
                phoneError: _phoneError,
                onSubmit: _save,
                onPhoneChanged: _clearPhoneError,
              ),
              Gap(28.fx),
              ContactFormActions(
                saveLabel: context.tr('safety.contacts.form.save'),
                deleteLabel: context.tr('safety.contacts.form.delete'),
                busy: busy,
                onSave: _save,
                onDelete: widget.editing ? _delete : null,
              ),
            ],
          ],
        );
      },
    );
  }
}
