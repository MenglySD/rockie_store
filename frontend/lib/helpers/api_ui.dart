import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rockie_store/provider/cart_provider.dart';
import 'package:rockie_store/services/api_exception.dart';
import 'package:rockie_store/theme/app_colors.dart';

/// User-facing message for any error thrown by a repository.
String errorMessage(Object error) =>
    error is ApiException ? error.message : 'Something went wrong. Please try again.';

/// Central error reporting for screens:
/// - 401 is handled globally (the user is sent to login), so nothing is shown.
/// - 409 refreshes the cart and shows the stock/coupon message.
/// - network / 5xx show a friendly message with an optional Retry action.
void showApiError(BuildContext context, Object error, {VoidCallback? onRetry}) {
  if (!context.mounted) return;
  if (error is ApiException && error.isUnauthorized) return;

  if (error is ApiException && error.isConflict) {
    context.read<CartProvider>().load();
  }

  final retryable = error is ApiException && error.isRetryable;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(errorMessage(error)),
        action: retryable && onRetry != null
            ? SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: onRetry)
            : null,
      ),
    );
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Shows Laravel 422 errors under the matching form fields.
///
/// Usage: in each field's validator call `serverErrors.of('email') ?? localCheck`,
/// clear the field in `onChanged`, and after a failed request call
/// [ServerErrors.apply], which re-runs validation to display the messages.
class ServerErrors {
  final Map<String, String> _errors = {};

  String? of(String field) => _errors[field];

  void clear([String? field]) => field == null ? _errors.clear() : _errors.remove(field);

  /// Returns true when at least one error matched a field in [fields]
  /// (so the caller does not also need a snackbar).
  bool apply(ApiException error, GlobalKey<FormState> formKey, {required Iterable<String> fields}) {
    _errors.clear();
    var matched = false;
    for (final field in fields) {
      final message = error.fieldError(field);
      if (message != null) {
        _errors[field] = message;
        matched = true;
      }
    }
    formKey.currentState?.validate();
    return matched;
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: mainColor));
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException &&
        ((error as ApiException).type == ApiErrorType.network ||
            (error as ApiException).type == ApiErrorType.timeout);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.wifi_off_rounded : Icons.error_outline,
              size: 56,
              color: const Color(0xFFB9B9B9),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mainColor,
                side: const BorderSide(color: mainColor),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFFB9B9B9)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF777777)),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small white spinner for buttons that are submitting.
class ButtonSpinner extends StatelessWidget {
  final Color color;
  const ButtonSpinner({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    width: 20,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}
