import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:safe_ride/core/constants/app_constants.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/core/shared_widgets/title_bar.dart';
import 'package:safe_ride/features/safety/logic/cubit/connections_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_links_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contact_reach_cubit.dart';
import 'package:safe_ride/features/safety/logic/cubit/contacts_cubit.dart';
import 'package:safe_ride/features/safety/presentation/widgets/connections_section.dart';
import 'package:safe_ride/features/safety/presentation/widgets/saved_contacts_section.dart';

/// The people the user trusts: accounts connected by an invite, then the
/// numbers kept for themselves. The screen says plainly what neither one does.
class TrustedContactsPage extends StatelessWidget {
  const TrustedContactsPage({super.key});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<ConnectionsCubit>(
        create: (_) => sl<ConnectionsCubit>()..load(),
      ),
      BlocProvider<ContactsCubit>(create: (_) => sl<ContactsCubit>()..load()),
      BlocProvider<ContactReachCubit>(create: (_) => sl<ContactReachCubit>()),
      if (AppFeatures.contactAlerts)
        BlocProvider<ContactLinksCubit>(
          create: (_) => sl<ContactLinksCubit>()..load(),
        ),
    ],
    child: Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) => ListView(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.screenSide,
              AppSpacing.screenTop,
              AppSpacing.screenSide,
              28.fx,
            ),
            children: <Widget>[
              TitleBar(title: context.tr('safety.contacts.title')),
              Gap(20.fx),
              const ConnectionsSection(),
              Gap(28.fx),
              const SavedContactsSection(),
            ],
          ),
        ),
      ),
    ),
  );
}
