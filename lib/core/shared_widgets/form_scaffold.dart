import 'package:flutter/material.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';

/// The frame of every form screen (login, register, plan and edit a journey,
/// a contact, the profile): a scrolling `Form` inside the safe area, so a
/// small phone, a large text size or the keyboard never overflows it.
class FormScaffold extends StatelessWidget {
  const FormScaffold({
    required this.formKey,
    required this.autovalidateMode,
    required this.children,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.screenSide,
            AppSpacing.screenTop,
            AppSpacing.screenSide,
            24.fx,
          ),
          child: Form(
            key: formKey,
            autovalidateMode: autovalidateMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
