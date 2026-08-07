import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:slickbill/color_scheme.dart';
import 'package:slickbill/feature_auth/services/monerium_service.dart';

class MoneriumKycStatusCard extends HookWidget {
  final String userId;

  const MoneriumKycStatusCard({super.key, required this.userId});

  static String _normalizeState(String? value) {
    final next = value?.trim().toLowerCase() ?? '';
    if (next.isEmpty) return 'unknown';
    return next;
  }

  static String _labelForState(String state) {
    switch (state) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending Review';
      case 'incomplete':
        return 'Incomplete';
      case 'created':
        return 'Created';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  static Color _colorForState(BuildContext context, String state) {
    switch (state) {
      case 'approved':
        return Theme.of(context).colorScheme.green;
      case 'pending':
      case 'incomplete':
      case 'created':
        return Theme.of(context).colorScheme.yellow;
      case 'rejected':
        return Theme.of(context).colorScheme.red;
      default:
        return Theme.of(context).colorScheme.darkGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final state = useState<String>('unknown');
    final detailsState = useState<String?>(null);
    final formState = useState<String?>(null);

    Future<void> loadStatus() async {
      if (userId.trim().isEmpty || userId == '0') {
        state.value = 'unknown';
        return;
      }

      isLoading.value = true;
      error.value = null;

      try {
        final response = await MoneriumService.getProfileStatus(userId: userId);
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          state.value = _normalizeState(data['state']?.toString());
          detailsState.value = data['detailsState']?.toString();
          formState.value = data['formState']?.toString();
        } else {
          state.value = 'unknown';
        }
      } catch (e) {
        final message = e.toString();
        if (message.contains('MONERIUM_NOT_CONNECTED')) {
          error.value = 'Connect Monerium to view KYC status.';
        } else {
          error.value = message;
        }
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      loadStatus();
      return null;
    }, [userId]);

    final resolvedState = state.value;
    final stateColor = _colorForState(context, resolvedState);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.light,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Monerium KYC Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.dark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: isLoading.value ? null : loadStatus,
                tooltip: 'Refresh KYC status',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (isLoading.value)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                color: Theme.of(context).colorScheme.blue,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _labelForState(resolvedState),
                  style: TextStyle(
                    color: stateColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (detailsState.value != null || formState.value != null) ...[
            const SizedBox(height: 10),
            Text(
              'Details: ${detailsState.value ?? '-'}  •  Form: ${formState.value ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.darkGray,
                  ),
            ),
          ],
          if (error.value != null) ...[
            const SizedBox(height: 10),
            Text(
              error.value!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.red,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
