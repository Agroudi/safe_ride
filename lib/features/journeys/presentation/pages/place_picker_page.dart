import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:safe_ride/core/di/service_locator.dart';
import 'package:safe_ride/core/extensions/figma_extensions.dart';
import 'package:safe_ride/features/journeys/data/models/journey_place.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_picker_cubit.dart';
import 'package:safe_ride/features/journeys/logic/cubit/place_search_cubit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/app_map.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_credit.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_defaults.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/map_markers.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_picker_card.dart';
import 'package:safe_ride/features/journeys/presentation/widgets/place_picker_top_bar.dart';

/// Choosing one end of a journey: search for it, use the phone's location,
/// tap the map, or drag the map under the pin. Pops with the [JourneyPlace],
/// or nothing when left. Nothing here is saved.
class PlacePickerPage extends StatelessWidget {
  const PlacePickerPage({required this.kind, this.initial, super.key});

  final MapPlaceKind kind;
  final JourneyPlace? initial;

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: <BlocProvider<dynamic>>[
      BlocProvider<PlaceSearchCubit>(create: (_) => sl<PlaceSearchCubit>()),
      BlocProvider<PlacePickerCubit>(
        create: (_) => sl<PlacePickerCubit>()..start(initial),
      ),
    ],
    child: _PlacePickerView(kind: kind, initial: initial),
  );
}

class _PlacePickerView extends StatefulWidget {
  const _PlacePickerView({required this.kind, required this.initial});

  final MapPlaceKind kind;
  final JourneyPlace? initial;

  @override
  State<_PlacePickerView> createState() => _PlacePickerViewState();
}

class _PlacePickerViewState extends State<_PlacePickerView> {
  final MapController _map = MapController();

  String get _language => context.locale.languageCode;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _pick(JourneyPlace place) {
    FocusScope.of(context).unfocus();
    context.read<PlacePickerCubit>().picked(place);
    _map.move(place.point, MapDefaults.closeZoom);
  }

  void _tap(LatLng point) {
    FocusScope.of(context).unfocus();
    context.read<PlacePickerCubit>().moved(point, languageCode: _language);
    _map.move(point, _map.camera.zoom);
  }

  void _moved(MapCamera camera, bool byUser) {
    if (byUser) {
      context.read<PlacePickerCubit>().moved(
        camera.center,
        languageCode: _language,
      );
    }
  }

  /// "Use my location" found the phone: the map goes there.
  void _located(BuildContext context, PlacePickerState state) {
    final LatLng? point = state.point;
    if (point != null) _map.move(point, MapDefaults.closeZoom);
  }

  void _confirm(PlacePickerState state) {
    final LatLng? point = state.point;
    if (point == null) return;
    context.pop(
      state.place ??
          JourneyPlace(
            name: context.tr('journeys.map.pinned'),
            lat: point.latitude,
            lng: point.longitude,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool start = widget.kind == MapPlaceKind.start;
    final JourneyPlace? initial = widget.initial;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BlocConsumer<PlacePickerCubit, PlacePickerState>(
        listenWhen: (PlacePickerState a, PlacePickerState b) =>
            a.locating && !b.locating && b.locationProblem == null,
        listener: _located,
        builder: (BuildContext context, PlacePickerState state) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: AppMap(
                controller: _map,
                center: initial?.point ?? MapDefaults.center,
                zoom: initial == null
                    ? MapDefaults.zoom
                    : MapDefaults.closeZoom,
                onTap: _tap,
                onMoved: _moved,
                showCredit: false,
                noticeTop: MediaQuery.paddingOf(context).top + 72.fx,
              ),
            ),
            if (state.point != null)
              Positioned.fill(
                child: CentredPlacePin(
                  kind: widget.kind,
                  label: context.tr(
                    start ? 'journeys.map.start' : 'journeys.map.destination',
                  ),
                ),
              ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: PlacePickerTopBar(
                hint: context.tr(
                  start
                      ? 'journeys.map.search.startHint'
                      : 'journeys.map.search.destinationHint',
                ),
                onPick: _pick,
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: 6.fx,
                      bottom: 4.fx,
                    ),
                    child: const MapCredit(extra: 'Photon'),
                  ),
                  PlacePickerCard(
                    state: state,
                    onConfirm: () => _confirm(state),
                    onLocate: () => context.read<PlacePickerCubit>().locate(
                      languageCode: _language,
                    ),
                    onSettings: context.read<PlacePickerCubit>().openSettings,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
