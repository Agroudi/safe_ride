import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/safety/logic/cubit/accept_connection_cubit.dart';

/// Pasting an invite: what a person does when the link opened in a browser.
class AcceptConnectionEntry extends StatefulWidget {
  const AcceptConnectionEntry({super.key});

  @override
  State<AcceptConnectionEntry> createState() => _AcceptConnectionEntryState();
}

class _AcceptConnectionEntryState extends State<AcceptConnectionEntry> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_form.currentState!.validate()) {
      context.read<AcceptConnectionCubit>().paste(_link.text);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InfoNote(text: context.tr('safety.connections.accept.entryNote')),
        Gap(20.fx),
        AppTextField(
          label: context.tr('safety.connections.accept.linkLabel'),
          controller: _link,
          keyboardType: TextInputType.url,
          validator: Validators.of(context).required,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        Gap(24.fx),
        AppPrimaryButton(
          label: context.tr('safety.connections.accept.continue'),
          onPressed: _submit,
        ),
      ],
    ),
  );
}
