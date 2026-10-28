import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/extensions/context_extensions.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/theme/app_colors.dart';

/// One trusted contact: initial, name, number and — when given — how the
/// user knows them. Tapping opens it to edit or delete; read as one item.
class ContactTile extends StatelessWidget {
  const ContactTile({
    required this.name,
    required this.phone,
    required this.onTap,
    this.relationship,
    super.key,
  });

  final String name;
  final String phone;
  final String? relationship;
  final VoidCallback onTap;

  /// [value] in a left-to-right isolate: a `+` and digits keep their order
  /// inside Arabic (CLAUDE.md §8).
  static String _ltr(String value) =>
      '${String.fromCharCode(0x2066)}$value${String.fromCharCode(0x2069)}';

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.appColors;
    final String? relation = relationship;

    return MergeSemantics(
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.fx),
          side: BorderSide(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14.fx),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44.fx,
                  height: 44.fx,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.tint(colors.secondary),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: context.texts.titleMedium?.copyWith(
                      color: colors.accentText,
                    ),
                  ),
                ),
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
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
