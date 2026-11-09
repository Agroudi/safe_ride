import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';
import 'package:safe_ride/features/safety/presentation/widgets/contact_initial.dart';

/// One trusted contact: initial, name, number, — when given — how the user
/// knows them, and any word on alerts. Tapping opens it to edit or delete;
/// read as one item. [actions] (Call, Message) sit below, outside that item,
/// so a screen reader reaches each on its own.
class ContactTile extends StatelessWidget {
  const ContactTile({
    required this.name,
    required this.phone,
    required this.onTap,
    this.alerts,
    this.relationship,
    this.actions,
    super.key,
  });

  final String name;
  final String phone;
  final String? relationship;
  final VoidCallback onTap;

  /// Whether alerts can reach them, in words; null in a build without them.
  final String? alerts;

  /// What can be done from the list besides opening it.
  final Widget? actions;

  /// [value] in a left-to-right isolate: a `+` and digits keep their order
  /// inside Arabic (CLAUDE.md §8).
  static String _ltr(String value) =>
      '${String.fromCharCode(0x2066)}$value${String.fromCharCode(0x2069)}';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? relation = relationship;
    final Widget? below = actions;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.fx),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(14.fx),
                child: Row(
                  children: <Widget>[
                    ContactInitial(name: name),
                    Gap(12.fx),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2.fx,
                        children: <Widget>[
                          Text(
                            name,
                            style: context.texts.titleSmall?.copyWith(
                              color: colors.text,
                            ),
                          ),
                          Text(
                            _ltr(phone),
                            style: context.texts.bodyMedium?.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                          if (relation != null)
                            Text(
                              relation,
                              style: context.texts.labelSmall?.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          if (alerts case final String words)
                            Text(
                              words,
                              style: context.texts.labelSmall?.copyWith(
                                color: colors.accentText,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: colors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          if (below != null)
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(64.fx, 0, 14.fx, 8.fx),
              child: below,
            ),
        ],
      ),
    );
  }
}
