import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/router/app_pages.dart';
import 'package:safe_ride/core/router/app_routes.dart';
import 'package:safe_ride/core/shared_widgets/app_back_button.dart';
import 'package:safe_ride/core/shared_widgets/app_empty_state.dart';
import 'package:safe_ride/features/journeys/logic/cubit/shared_view_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/shared_view_map.dart';

/// What opens from a share's link when SafeRide is installed: no account, and
/// nothing here can change anything. The token comes from the link's `#` part
/// and goes no further than the read.
class SharedViewPage extends StatelessWidget {
  const SharedViewPage({required this.token, super.key});

  final String? token;

  /// A link can open the app with nothing beneath this screen: then the
  /// splash decides where it belongs.
  static void leave(BuildContext context) => context.canPop()
      ? context.pop()
      : context.goNamed(AppRoutes.splash, extra: AppPages.up);

  @override
  Widget build(BuildContext context) => BlocProvider<SharedViewCubit>(
    create: (_) => sl<SharedViewCubit>()..open(token),
    child: const _SharedView(),
  );
}

class _SharedView extends StatelessWidget {
  const _SharedView();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BlocBuilder<SharedViewCubit, SharedViewState>(
      buildWhen: (SharedViewState a, SharedViewState b) => a.phase != b.phase,
      builder: (BuildContext context, SharedViewState state) =>
          switch (state.phase) {
            SharedViewPhase.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            SharedViewPhase.ready => const SharedViewMap(),
            SharedViewPhase.ended => _Message(
              icon: Icons.link_off_rounded,
              title: context.tr('sharing.view.ended.title'),
              body: context.tr('sharing.view.ended.body'),
            ),
            SharedViewPhase.unreachable => _Message(
              icon: Icons.cloud_off_rounded,
              title: context.tr('sharing.view.unreachable.title'),
              body: context.tr('sharing.view.unreachable.body'),
            ),
          },
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: <Widget>[
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AppBackButton(onPressed: () => SharedViewPage.leave(context)),
        ),
        AppEmptyState(icon: icon, title: title, body: body),
      ],
    ),
  );
}
