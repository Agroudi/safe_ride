import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:safe_ride/core/country/country.dart';
import 'package:safe_ride/core/country/country_cubit.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/shared_widgets/country_picker_sheet.dart';
import 'package:safe_ride/core/shared_widgets/link_tile.dart';

/// Profile's row for the country the user is in — the one the emergency
/// numbers follow. Shows it (or that none is chosen) and changes it.
class CountryTile extends StatelessWidget {
  const CountryTile({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider<CountryCubit>(
    create: (_) => sl<CountryCubit>(),
    child: BlocBuilder<CountryCubit, CountryState>(
      builder: (BuildContext context, CountryState state) {
        final Country? country = state.country;
        return LinkTile(
          icon: Icons.public_rounded,
          title: context.tr('country.title'),
          body: country == null
              ? context.tr('country.notChosen')
              : '${country.flag}  ${country.name(context.locale.languageCode)}',
          onTap: () async {
            final CountryCubit cubit = context.read<CountryCubit>();
            final String? code = await showCountryPicker(
              context,
              selected: country?.code,
            );
            if (code != null) await cubit.choose(code);
          },
        );
      },
    ),
  );
}
