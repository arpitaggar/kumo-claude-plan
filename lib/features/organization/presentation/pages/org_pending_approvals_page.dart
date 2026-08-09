import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../../domain/entities/pending_expense_approval.dart';
import '../providers/organization_provider.dart';

class OrgPendingApprovalsPage extends ConsumerWidget {
  const OrgPendingApprovalsPage({required this.orgId, super.key});

  final String orgId;

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    PendingExpenseApproval approval,
  ) async {
    final result = await ref
        .read(reviewExpenseUseCaseProvider)
        .approve(approval.expenseId);
    if (!context.mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {
      ref.invalidate(pendingApprovalsProvider(orgId));
      context.showSnackBar('Approved');
    });
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    PendingExpenseApproval approval,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject expense?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colorScheme.error,
            ),
            onPressed: () => ctx.pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final result = await ref
        .read(reviewExpenseUseCaseProvider)
        .reject(
          approval.expenseId,
          reasonController.text.trim().isEmpty
              ? 'No reason given'
              : reasonController.text.trim(),
        );
    if (!context.mounted) {
      return;
    }
    result.fold((f) => context.showSnackBar(f.message, isError: true), (_) {
      ref.invalidate(pendingApprovalsProvider(orgId));
      context.showSnackBar('Rejected');
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final approvalsAsync = ref.watch(pendingApprovalsProvider(orgId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: approvalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (approvals) {
          if (approvals.isEmpty) {
            return Center(
              child: Text(
                'Nothing waiting for review',
                style: TextStyle(color: context.colorScheme.onSurfaceVariant),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: approvals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final approval = approvals[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      approval.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${approval.tripTitle} · ${approval.payerName} · '
                      '${DateFormat('MMM d').format(approval.submittedAt.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (approval.notes != null &&
                        approval.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        approval.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (approval.costCenterCode != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          approval.costCenterCode!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${approval.amount.toStringAsFixed(2)} ${approval.currencyCode}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _reject(context, ref, approval),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colorScheme.error,
                          ),
                          child: const Text('Reject'),
                        ),
                        FilledButton(
                          onPressed: () => _approve(context, ref, approval),
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
