import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/notifications/app_notification.dart';
import 'package:safe_ride/core/notifications/app_notifier.dart';
import 'package:safe_ride/core/shared_widgets/app_primary_button.dart';
import 'package:safe_ride/core/shared_widgets/app_text_field.dart';
import 'package:safe_ride/core/shared_widgets/form_scaffold.dart';
import 'package:safe_ride/core/shared_widgets/info_note.dart';
import 'package:safe_ride/core/shared_widgets/section_heading.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/core/validation/validators.dart';
import 'package:safe_ride/features/safety/data/models/connection_failure.dart';
import 'package:safe_ride/features/safety/data/models/connection_model.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_access_card.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_actions.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connection_labels.dart';

/// One connection: what it allows, the user's own word for this person, and
/// the way to end it.
class ManageConnectionForm extends StatefulWidget {
  const ManageConnectionForm({
    required this.connection,
    required this.busy,
    super.key,
  });

  final ConnectionModel connection;
  final bool busy;

  @override
  State<ManageConnectionForm> createState() => _ManageConnectionFormState();
}

class _ManageConnectionFormState extends State<ManageConnectionForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  late final TextEditingController _nickname = TextEditingController(
    text: widget.connection.nickname,
  );

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final ConnectionFailureCode? failure = await context
        .read<ConnectionsCubit>()
        .rename(widget.connection.contactUid, _nickname.text);
    if (!mounted) return;
    sl<AppNotifier>().show(
      failure == null
          ? AppNotification.success(
              title: context.tr('safety.connections.manageScreen.saved'),
            )
          : ConnectionLabels.failure(context, failure),
    );
  }

  Future<void> _remove() async {
    if (await ConnectionActions.remove(context, widget.connection) && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConnectionModel c = widget.connection;

    return FormScaffold(
      formKey: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      children: <Widget>[
        TitleBar(title: c.displayName),
        Gap(8.fx),
        Text(
          context.tr(
            'safety.connections.since',
            namedArgs: <String, String>{
              'date': ConnectionLabels.date(context, c.acceptedAt),
            },
          ),
          style: context.texts.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        Gap(20.fx),
        SectionHeading(
          title: context.tr('safety.connections.manageScreen.accessHeading'),
        ),
        Gap(10.fx),
        ConnectionAccessCard(connection: c),
        Gap(10.fx),
        InfoNote(text: context.tr('safety.connections.manageScreen.separate')),
        Gap(24.fx),
        AppTextField(
          label: context.tr('safety.connections.manageScreen.nicknameLabel'),
          hint: c.contactName,
          helperText: context.tr(
            'safety.connections.manageScreen.nicknameHelper',
          ),
          controller: _nickname,
          validator: Validators.of(context).nickname,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        Gap(16.fx),
        AppPrimaryButton(
          label: context.tr('safety.connections.manageScreen.save'),
          busy: widget.busy,
          onPressed: _save,
        ),
        Gap(12.fx),
        AppPrimaryButton(
          label: context.tr('safety.connections.remove'),
          outlined: true,
          color: context.appColors.error,
          foregroundColor: context.appColors.error,
          onPressed: widget.busy ? null : _remove,
        ),
      ],
    );
  }
}
