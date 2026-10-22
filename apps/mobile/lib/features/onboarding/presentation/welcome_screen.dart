/// AOnboard1–3 — first screens of a signed-out install: what SaveStream does
/// (cloud recording, own channels only, bio-code verification) and the two
/// ways into auth.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    required this.session,
    required this.settings,
    required this.config,
    this.initialPage = 0,
    super.key,
  });

  final AppSessionController session;
  final AppSettingsController settings;
  final AppConfig config;
  final int initialPage;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  static const int _pageCount = 3;
  late final PageController _pages = PageController(
    initialPage: widget.initialPage,
  );
  late int _index = widget.initialPage;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _continueTo(String route) {
    widget.session.completeOnboarding();
    context.go(route);
  }

  void _next() {
    _pages.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool last = _index == _pageCount - 1;

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
            child: SizedBox(
              // Skip's 12px tap padding makes the bar 43px; without it, 28px.
              height: last ? 28 : 43,
              child: Row(
                children: <Widget>[
                  const SsV2LogoMark(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.appTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!last)
                    Semantics(
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _continueTo(AppRoutes.register),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            l10n.v2Skip,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: palette.link,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (int value) => setState(() => _index = value),
              children: const <Widget>[
                _Slide(page: 0),
                _Slide(page: 1),
                _Slide(page: 2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SsV2PageDots(
                  count: _pageCount,
                  index: _index,
                  semanticLabel: l10n.v2SlideLabel(_index + 1, _pageCount),
                ),
                const SizedBox(height: 20),
                SsV2Button(
                  label: last ? l10n.v2CreateAccount : l10n.v2Next,
                  onPressed: last
                      ? () => _continueTo(AppRoutes.register)
                      : _next,
                ),
                if (last) ...<Widget>[
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: <Widget>[
                      Text(
                        '${l10n.v2HaveAccountPrompt} ',
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.textMuted,
                        ),
                      ),
                      SsV2Link(
                        label: l10n.v2SignIn,
                        onPressed: () => _continueTo(AppRoutes.signIn),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.page});

  final int page;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final (String title, String body, Widget art) = switch (page) {
      0 => (l10n.v2Onboard1Title, l10n.v2Onboard1Body, const _CloudArt()),
      1 => (l10n.v2Onboard2Title, l10n.v2Onboard2Body, const _ChannelsArt()),
      _ => (l10n.v2Onboard3Title, l10n.v2Onboard3Body, const _BioCodeArt()),
    };
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: ExcludeSemantics(child: art)),
                const SizedBox(height: 28),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CloudArt extends StatelessWidget {
  const _CloudArt();

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final AppLocalizations l10n = context.l10n;
    return Container(
      width: 260,
      height: 220,
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 128,
            height: 176,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF15122B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.error,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    l10n.v2ChipRec,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.v2Onboard1Saved,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            top: 20,
            child: SsV2Icon(
              SsV2IconGlyph.cloud,
              size: 64,
              strokeWidth: 1.8,
              color: palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelsArt extends StatelessWidget {
  const _ChannelsArt();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SizedBox(
      width: 280,
      child: Column(
        children: <Widget>[
          _SampleChannel(
            handle: '@my_shop_live',
            status: l10n.v2Onboard2SampleRecording,
            chip: SsV2StatusChip(
              label: l10n.v2ChipRec,
              tone: SsV2ChipTone.recording,
            ),
            live: true,
          ),
          const SizedBox(height: 10),
          _SampleChannel(
            handle: '@my_gaming_stream',
            status: l10n.v2Onboard2SampleWaiting,
            chip: SsV2StatusChip(
              label: l10n.v2ChipWaiting,
              tone: SsV2ChipTone.waiting,
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleChannel extends StatelessWidget {
  const _SampleChannel({
    required this.handle,
    required this.status,
    required this.chip,
    this.live = false,
  });

  final String handle;
  final String status;
  final Widget chip;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: <Widget>[
          SsV2Avatar(name: handle, liveRing: live),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 13, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          chip,
        ],
      ),
    );
  }
}

class _BioCodeArt extends StatelessWidget {
  const _BioCodeArt();

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final AppLocalizations l10n = context.l10n;
    return Container(
      // 280px content + padding + border (CSS content-box in the artboard).
      width: 318,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.v2Onboard3CodeLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: palette.tintSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'SS-7K4Q',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.72,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              SsV2Icon(SsV2IconGlyph.check, size: 18, color: palette.success),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l10n.v2Onboard3Verified,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
