import 'package:flutter/material.dart';

import '../../app/theme/ss_tokens.dart';
import '../../l10n/l10n.dart';
import '../api/api_exception.dart';
import '../mock/mock_repository_base.dart';
import 'ss_states.dart';

enum SsAsyncErrorKind { offline, recoverable, nonRecoverable }

final class SsAsyncErrorDetails {
  const SsAsyncErrorDetails({
    required this.kind,
    required this.title,
    required this.message,
    required this.retryable,
    this.requestId,
  });

  final SsAsyncErrorKind kind;
  final String title;
  final String message;
  final bool retryable;
  final String? requestId;
}

SsAsyncErrorDetails describeAsyncError(
  BuildContext context,
  Object error, {
  String? titleOverride,
  String? messageOverride,
  bool? retryableOverride,
}) {
  final AppLocalizations l10n = context.l10n;

  if (_isOfflineLike(error)) {
    return SsAsyncErrorDetails(
      kind: SsAsyncErrorKind.offline,
      title: titleOverride ?? l10n.offlineErrorTitle,
      message: messageOverride ?? l10n.offlineErrorBody,
      retryable: retryableOverride ?? true,
      requestId: error is ApiException ? error.requestId : null,
    );
  }

  final bool apiRetryable = error is ApiException && error.retryable;
  final bool mockRetryable =
      error is MockRepositoryException && error.kind == MockFailureKind.server;
  final bool retryable = retryableOverride ?? (apiRetryable || mockRetryable);

  return SsAsyncErrorDetails(
    kind: retryable
        ? SsAsyncErrorKind.recoverable
        : SsAsyncErrorKind.nonRecoverable,
    title:
        titleOverride ??
        (retryable ? l10n.errorTitle : l10n.nonRetryableErrorTitle),
    message:
        messageOverride ??
        (retryable ? l10n.errorBody : l10n.nonRetryableErrorBody),
    retryable: retryable,
    requestId: error is ApiException ? error.requestId : null,
  );
}

class SsAsyncErrorState extends StatelessWidget {
  const SsAsyncErrorState({
    required this.error,
    this.onRetry,
    this.titleOverride,
    this.messageOverride,
    this.retryableOverride,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;
  final String? titleOverride;
  final String? messageOverride;
  final bool? retryableOverride;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsAsyncErrorDetails details = describeAsyncError(
      context,
      error,
      titleOverride: titleOverride,
      messageOverride: messageOverride,
      retryableOverride: retryableOverride,
    );

    return SsErrorState(
      title: details.title,
      message: details.message,
      retryLabel: details.retryable && onRetry != null
          ? l10n.retryAction
          : null,
      onRetry: details.retryable ? onRetry : null,
      details: details.requestId == null
          ? null
          : l10n.requestIdLabel(details.requestId!),
    );
  }
}

class SsAsyncRefreshFrame extends StatelessWidget {
  const SsAsyncRefreshFrame({
    required this.isRefreshing,
    required this.child,
    super.key,
  });

  final bool isRefreshing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        if (isRefreshing)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Semantics(
              label: context.l10n.refreshingLabel,
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          ),
      ],
    );
  }
}

class SsInlineAsyncError extends StatelessWidget {
  const SsInlineAsyncError({
    required this.error,
    this.onRetry,
    this.messageOverride,
    this.retryableOverride,
    super.key,
  });

  final Object error;
  final VoidCallback? onRetry;
  final String? messageOverride;
  final bool? retryableOverride;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsAsyncErrorDetails details = describeAsyncError(
      context,
      error,
      messageOverride: messageOverride,
      retryableOverride: retryableOverride,
    );
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SsSpacing.md),
      decoration: BoxDecoration(
        color: details.kind == SsAsyncErrorKind.offline
            ? colors.tertiaryContainer
            : colors.errorContainer,
        borderRadius: BorderRadius.circular(SsRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            details.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: details.kind == SsAsyncErrorKind.offline
                  ? colors.onTertiaryContainer
                  : colors.onErrorContainer,
            ),
          ),
          if (details.requestId != null) ...<Widget>[
            const SizedBox(height: SsSpacing.xs),
            SelectableText(
              l10n.requestIdLabel(details.requestId!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (details.retryable && onRetry != null) ...<Widget>[
            const SizedBox(height: SsSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(l10n.retryAction)),
          ],
        ],
      ),
    );
  }
}

bool _isOfflineLike(Object error) {
  return (error is MockRepositoryException &&
          error.kind == MockFailureKind.offlineLike) ||
      (error is ApiException &&
          (error.kind == ApiExceptionKind.network ||
              error.kind == ApiExceptionKind.timeout));
}
