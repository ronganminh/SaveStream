/// AAddSheet · AAddFound · AAddNotFound — the Add channel bottom sheet.
///
/// Enter a username → the server looks up the public profile
/// (`POST /v1/live-status`) → "Is this your channel?" with the ownership
/// confirmation → the channel is created (`POST /v1/watches`, owner_attested)
/// and the sheet closes with it so the caller can open Verify ownership.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/models/watch_summary.dart';
import 'controllers/watch_providers.dart';

/// Opens the sheet; completes with the created channel, or null when closed.
Future<WatchSummary?> showAddChannelSheet(BuildContext context) {
  return showSsV2Sheet<WatchSummary>(
    context: context,
    builder: (BuildContext sheetContext) => const AddChannelSheet(),
  );
}

final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9._]{2,24}$');
final RegExp _profileUrl = RegExp(
  r'^(?:https?://)?(?:www\.|m\.)?tiktok\.com/@([A-Za-z0-9._]{2,24})(?:[/?#].*)?$',
  caseSensitive: false,
);

/// The username typed or pasted (with or without @, or a profile link).
String normalizeTikTokUsername(String raw) {
  final String value = raw.trim();
  final RegExpMatch? link = _profileUrl.firstMatch(value);
  if (link != null) return link.group(1)!;
  return value.startsWith('@') ? value.substring(1) : value;
}

enum _Step { enter, found, notFound }

class AddChannelSheet extends ConsumerStatefulWidget {
  const AddChannelSheet({super.key});

  @override
  ConsumerState<AddChannelSheet> createState() => _AddChannelSheetState();
}

class _AddChannelSheetState extends ConsumerState<AddChannelSheet> {
  final TextEditingController _username = TextEditingController();
  late final TapGestureRecognizer _aup = TapGestureRecognizer()
    ..onTap = _openPolicy;

  _Step _step = _Step.enter;
  CreatorLookupResult? _found;
  String? _fieldError;
  bool _notFoundHelp = false;
  bool _busy = false;
  bool _owner = false;
  bool _ownerError = false;
  String? _createError;

  @override
  void dispose() {
    _username.dispose();
    _aup.dispose();
    super.dispose();
  }

  Future<void> _openPolicy() async {
    await launchUrl(
      ref.read(appConfigProvider).acceptableUseUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _find() async {
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    final String username = normalizeTikTokUsername(_username.text);
    if (username.isEmpty) {
      setState(() => _fieldError = l10n.v2UsernameRequired);
      return;
    }
    if (!_usernamePattern.hasMatch(username)) {
      setState(() => _fieldError = l10n.v2UsernameInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _fieldError = null;
    });
    try {
      final CreatorLookupResult result = await ref
          .read(creatorLookupRepositoryProvider)
          .lookupCreator(
            CreateWatchCommand(
              sourceType: WatchSourceType.username,
              sourceValue: username,
              autoRecord: false,
            ),
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _found = result;
        _owner = false;
        _ownerError = false;
        _createError = null;
        _step = _Step.found;
      });
    } on Object catch (error) {
      if (!mounted) return;
      final bool unreachable =
          error is ApiException &&
          (error.kind == ApiExceptionKind.network ||
              error.kind == ApiExceptionKind.timeout);
      setState(() {
        _busy = false;
        _step = _Step.notFound;
        // The API answers an unknown username with STREAM_UNAVAILABLE (503),
        // the same as a TikTok outage, so only a dropped connection gets the
        // "couldn't reach" copy.
        _notFoundHelp = !unreachable;
        _fieldError = unreachable
            ? l10n.v2LookupUnavailable
            : l10n.v2ChannelNotFound;
      });
    }
  }

  Future<void> _confirm() async {
    final CreatorLookupResult? found = _found;
    if (found == null || _busy) return;
    if (!_owner) {
      setState(() => _ownerError = true);
      return;
    }
    setState(() {
      _busy = true;
      _createError = null;
    });
    try {
      final WatchSummary created = await ref
          .read(watchControllerProvider)
          .createWatch(
            CreateWatchCommand(
              sourceType: WatchSourceType.username,
              sourceValue: found.username.replaceFirst('@', ''),
              // Off until the channel is verified; turned on from the
              // "verified" screen.
              autoRecord: false,
              notifyOnLive: false,
              ownerAttested: true,
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on Object catch (error) {
      if (!mounted) return;
      final AppLocalizations l10n = context.l10n;
      setState(() {
        _busy = false;
        _createError = error is ApiException && error.statusCode == 409
            ? l10n.v2ChannelAlreadyAdded
            : l10n.v2AddChannelFailed;
      });
    }
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('add-channel-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: ssV2Gap(switch (_step) {
        _Step.enter => _enter(context),
        _Step.notFound => _notFound(context),
        _Step.found => _confirmation(context),
      }, 16),
    );
  }

  Widget _title(String text) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _field(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2TextField(
      fieldKey: const ValueKey<String>('add-channel-username'),
      label: l10n.v2TikTokUsername,
      hintText: l10n.v2UsernameHint,
      controller: _username,
      errorText: _fieldError,
      helperText: _step == _Step.enter ? l10n.v2UsernameHelper : null,
      autocorrect: false,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.search,
      onChanged: (_) {
        if (_fieldError != null && _step == _Step.enter) {
          setState(() => _fieldError = null);
        }
      },
      onSubmitted: (_) => _find(),
    );
  }

  List<Widget> _enter(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(child: _title(l10n.v2AddChannelTitle)),
          SizedBox.square(
            dimension: 48,
            child: IconButton(
              tooltip: l10n.v2Close,
              onPressed: _close,
              icon: SsV2Icon(SsV2IconGlyph.close, color: palette.text),
            ),
          ),
        ],
      ),
      Text(
        l10n.v2AddChannelBody,
        style: TextStyle(fontSize: 14, height: 1.5, color: palette.textMuted),
      ),
      _field(context),
      SsV2Button(label: l10n.v2FindChannel, isLoading: _busy, onPressed: _find),
      SsV2Disclaimer(text: l10n.v2NotAffiliated),
    ];
  }

  List<Widget> _notFound(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return <Widget>[
      _title(l10n.v2AddChannelTitle),
      _field(context),
      if (_notFoundHelp)
        SsV2Banner(
          tone: SsV2Tone.info,
          glyph: SsV2IconGlyph.help,
          child: Text(l10n.v2ChannelNotFoundHelp),
        ),
      SsV2Button(label: l10n.v2Retry, isLoading: _busy, onPressed: _find),
      SsV2Button(
        label: l10n.v2Cancel,
        variant: SsV2ButtonVariant.text,
        onPressed: _close,
      ),
    ];
  }

  List<Widget> _confirmation(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final CreatorLookupResult found = _found!;
    final String handle = '@${found.username.replaceFirst('@', '')}';
    final String displayName = found.displayName.trim();
    return <Widget>[
      _title(l10n.v2IsThisYourChannel),
      SsV2Card(
        child: Row(
          children: <Widget>[
            SsV2Avatar(name: handle, size: 52, fontSize: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    handle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // The API has no follower count, so only the profile's
                  // display name is shown under the handle.
                  if (displayName.isNotEmpty &&
                      displayName.toLowerCase() !=
                          handle.substring(1).toLowerCase()) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: palette.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SsV2StatusChip(label: l10n.v2ChipFound, tone: SsV2ChipTone.success),
          ],
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MergeSemantics(
            child: GestureDetector(
              key: const ValueKey<String>('add-channel-owner'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _owner = !_owner;
                if (_owner) _ownerError = false;
              }),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SsV2Checkbox(
                    value: _owner,
                    hasError: _ownerError,
                    onChanged: (bool value) => setState(() {
                      _owner = value;
                      if (value) _ownerError = false;
                    }),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: <InlineSpan>[
                          TextSpan(text: l10n.v2OwnershipConsentLead),
                          TextSpan(
                            text: l10n.v2AcceptableUsePolicy,
                            style: TextStyle(
                              color: palette.link,
                              decoration: TextDecoration.underline,
                              decorationColor: palette.link,
                            ),
                            recognizer: _aup,
                          ),
                          TextSpan(text: l10n.v2OwnershipConsentTail),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: palette.textConsent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_ownerError) ...<Widget>[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: SsV2InlineError(message: l10n.v2OwnershipConsentError),
            ),
          ],
        ],
      ),
      if (_createError != null) SsV2InlineError(message: _createError!),
      SsV2Button(
        label: l10n.v2YesVerifyOwnership,
        isLoading: _busy,
        onPressed: _confirm,
      ),
      SsV2Button(
        label: l10n.v2NotMyChannel,
        variant: SsV2ButtonVariant.text,
        onPressed: _busy
            ? null
            : () => setState(() {
                _step = _Step.enter;
                _found = null;
              }),
      ),
    ];
  }
}
