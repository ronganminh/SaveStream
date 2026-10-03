/// W04–W08 — Add creator states.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/savestream_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../entitlement/domain/models/entitlement.dart';
import '../../entitlement/presentation/entitlement_providers.dart';
import '../domain/models/watch_summary.dart';
import 'cloud_hours_upsell_sheet.dart';
import 'controllers/watch_providers.dart';

enum _LookupState { idle, checking, found, notFound, restricted, unavailable }

class AddChannelScreen extends ConsumerStatefulWidget {
  const AddChannelScreen({super.key});

  @override
  ConsumerState<AddChannelScreen> createState() => _AddChannelScreenState();
}

class _AddChannelScreenState extends ConsumerState<AddChannelScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _sourceController = TextEditingController();

  _LookupState _lookupState = _LookupState.idle;
  bool _submitting = false;
  Object? _error;

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  String get _source => _sourceController.text.trim();

  String get _username {
    final String raw = _source;
    final Uri? uri = Uri.tryParse(raw);
    final String value =
        uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : raw;
    return value.replaceFirst('@', '');
  }

  String get _handle {
    final String value = _username;
    return value.isEmpty ? '@creator' : '@$value';
  }

  String get _displayName {
    final String value = _username;
    if (value.isEmpty) return 'TikTok creator';
    return value
        .split(RegExp(r'[_\-.]+'))
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) =>
              part.substring(0, 1).toUpperCase() + part.substring(1),
        )
        .join(' ');
  }

  Future<void> _lookup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _lookupState = _LookupState.checking;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    final String normalized = _source.toLowerCase();
    final _LookupState next;
    if (normalized.contains('missing') || normalized.contains('notfound')) {
      next = _LookupState.notFound;
    } else if (normalized.contains('private') ||
        normalized.contains('douyin.com')) {
      next = _LookupState.restricted;
    } else if (normalized.contains('unavailable') ||
        normalized.contains('restricted')) {
      next = _LookupState.unavailable;
    } else {
      next = _LookupState.found;
    }
    setState(() => _lookupState = next);
  }

  Future<void> _create(Entitlement entitlement) async {
    if (_lookupState != _LookupState.found || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final WatchSourceType sourceType =
        _source.startsWith('http://') || _source.startsWith('https://')
        ? WatchSourceType.url
        : WatchSourceType.username;
    try {
      final WatchSummary created = await ref
          .read(watchControllerProvider)
          .createWatch(
            CreateWatchCommand(
              sourceType: sourceType,
              sourceValue: _source,
              autoRecord: false,
              notifyOnLive: true,
            ),
          );
      if (!mounted) return;
      context.go(AppRoutes.channelDetail(created.id));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _submitting = false;
      });
    }
  }

  void _resetLookup() {
    setState(() {
      _lookupState = _LookupState.idle;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Entitlement> entitlement = ref.watch(entitlementProvider);
    final AsyncValue<List<WatchSummary>> watches = ref.watch(watchListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.addCreatorTitle)),
      body: SafeArea(
        child: entitlement.when(
          loading: () => const _AddSkeleton(),
          error: (Object error, StackTrace stack) => Center(
            child: SsAsyncErrorState(
              error: error,
              onRetry: () => ref.invalidate(entitlementProvider),
            ),
          ),
          data: (Entitlement access) => watches.when(
            loading: () => const _AddSkeleton(),
            error: (Object error, StackTrace stack) => Center(
              child: SsAsyncErrorState(
                error: error,
                onRetry: () => ref.invalidate(watchListProvider),
              ),
            ),
            data: (List<WatchSummary> items) {
              final int limit = access.limits.maxWatches;
              if (items.length >= limit) {
                return _LimitBlocked(
                  count: items.length,
                  limit: limit,
                  onBuy: () => showCloudHoursUpsellSheet(context),
                );
              }
              return _form(access, items.length, limit);
            },
          ),
        ),
      ),
    );
  }

  Widget _form(Entitlement entitlement, int count, int limit) {
    final AppLocalizations l10n = context.l10n;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.addCreatorHeading,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: SsSpacing.sm),
                Text(l10n.addCreatorBody),
                const SizedBox(height: SsSpacing.sm),
                Text(l10n.homeWatchingCapacity(count, limit)),
                const SizedBox(height: SsSpacing.lg),
                Wrap(
                  spacing: SsSpacing.sm,
                  runSpacing: SsSpacing.sm,
                  children: <Widget>[
                    SsStatusChip(
                      label: l10n.tiktokSupportedLabel,
                      icon: Icons.music_note_rounded,
                      tone: SsStatusTone.success,
                    ),
                    SsStatusChip(label: l10n.douyinComingSoonLabel),
                  ],
                ),
                const SizedBox(height: SsSpacing.xl),
                SsTextField(
                  label: l10n.onboardingCreatorSourceLabel,
                  hintText: l10n.channelSourceHint,
                  controller: _sourceController,
                  prefixIcon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) {
                    if (_lookupState != _LookupState.idle) {
                      _resetLookup();
                    }
                  },
                  onFieldSubmitted: (_) => _lookup(),
                  validator: (String? value) {
                    final String source = value?.trim() ?? '';
                    if (source.isEmpty) return l10n.channelSourceRequired;
                    if (source.contains(' ') || source == '@') {
                      return l10n.channelSourceInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SsSpacing.lg),
                if (_error != null) ...<Widget>[
                  SsAsyncErrorState(
                    error: _error!,
                    messageOverride: _errorMessage(l10n, _error!),
                    onRetry: () => _create(entitlement),
                  ),
                  const SizedBox(height: SsSpacing.lg),
                ],
                _lookupBody(entitlement),
                if (_lookupState == _LookupState.idle) ...<Widget>[
                  SsPrimaryButton(
                    label: l10n.creatorLookupAction,
                    icon: Icons.search_rounded,
                    onPressed: _lookup,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lookupBody(Entitlement entitlement) {
    final AppLocalizations l10n = context.l10n;
    return switch (_lookupState) {
      _LookupState.idle => const SizedBox.shrink(),
      _LookupState.checking => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsSkeleton(height: 88, radius: SsRadii.lg),
          SizedBox(height: SsSpacing.lg),
        ],
      ),
      _LookupState.found => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SsStatusChip(
                  label: l10n.creatorFoundLabel,
                  icon: Icons.check_circle_rounded,
                  tone: SsStatusTone.success,
                ),
                const SizedBox(height: SsSpacing.md),
                SsListTile(
                  title: _displayName,
                  subtitle: '$_handle · TikTok',
                  leading: SsAvatar(label: _displayName),
                ),
              ],
            ),
          ),
          const SizedBox(height: SsSpacing.md),
          SsInlineAlert(
            title: l10n.responsibleUseReminderTitle,
            message: l10n.responsibleUseReminderBody,
            tone: SsInlineAlertTone.info,
          ),
          const SizedBox(height: SsSpacing.lg),
          SsPrimaryButton(
            label: l10n.addAndFollowAction,
            isLoading: _submitting,
            onPressed: () => _create(entitlement),
          ),
        ],
      ),
      _LookupState.notFound => _LookupFailure(
        title: l10n.creatorNotFoundTitle,
        body: l10n.creatorNotFoundBody(_handle),
        onTryAgain: _resetLookup,
      ),
      _LookupState.restricted => _LookupFailure(
        title: l10n.creatorRestrictedTitle,
        body: l10n.creatorRestrictedBody,
        onTryAgain: _resetLookup,
      ),
      _LookupState.unavailable => _LookupFailure(
        title: l10n.creatorUnavailableTitle,
        body: l10n.creatorUnavailableBody,
        onTryAgain: _resetLookup,
      ),
    };
  }
}

class _LookupFailure extends StatelessWidget {
  const _LookupFailure({
    required this.title,
    required this.body,
    required this.onTryAgain,
  });

  final String title;
  final String body;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsInlineAlert(
          title: title,
          message: body,
          tone: SsInlineAlertTone.warning,
        ),
        const SizedBox(height: SsSpacing.lg),
        SsSecondaryButton(
          label: context.l10n.tryAnotherCreatorAction,
          onPressed: onTryAgain,
        ),
      ],
    );
  }
}

class _LimitBlocked extends StatelessWidget {
  const _LimitBlocked({
    required this.count,
    required this.limit,
    required this.onBuy,
  });

  final int count;
  final int limit;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SsSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(Icons.group_add_outlined, size: 64),
              const SizedBox(height: SsSpacing.lg),
              Text(
                context.l10n.watchLimitTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SsSpacing.sm),
              Text(
                count > limit
                    ? context.l10n.watchCapacityLegacyExceeded(count)
                    : context.l10n.creatorLimitDirectBody,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SsSpacing.xl),
              SsPrimaryButton(
                label: context.l10n.buyCloudHoursAction,
                onPressed: onBuy,
              ),
              const SizedBox(height: SsSpacing.sm),
              SsSecondaryButton(
                label: context.l10n.manageWatchingAction,
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddSkeleton extends StatelessWidget {
  const _AddSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(SsSpacing.lg),
      children: const <Widget>[
        SsSkeleton(width: 220, height: 32),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 56, radius: SsRadii.md),
        SizedBox(height: SsSpacing.lg),
        SsSkeleton(height: 96, radius: SsRadii.lg),
      ],
    );
  }
}

String? _errorMessage(AppLocalizations l10n, Object error) {
  if (error is ApiException && error.code == 'WATCH_LIMIT_REACHED') {
    return l10n.creatorLimitDirectBody;
  }
  if (error is ApiException && error.kind == ApiExceptionKind.conflict) {
    return l10n.watchAlreadyExistsMessage;
  }
  return null;
}
