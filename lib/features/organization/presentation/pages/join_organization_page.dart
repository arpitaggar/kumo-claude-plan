import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../shared/extensions/context_extensions.dart';
import '../providers/organization_provider.dart';

/// Employee-facing screen to self-serve join an organization via a code an
/// admin generated on [OrgJoinCodesPage] — scan its QR or type it in. Both
/// paths resolve to the same [redeemOrgJoinCodeUseCaseProvider] call; the
/// server (`redeem_org_join_code`) is the sole authority on which org/user
/// the code actually grants, never anything read from the QR/text locally.
class JoinOrganizationPage extends ConsumerStatefulWidget {
  const JoinOrganizationPage({this.initialCode, super.key});

  /// Pre-fills the manual-entry field — set when arriving via a
  /// `kumo://join?code=XYZ` deep link (see `lib/config/router.dart`'s
  /// redirect()) rather than the in-app "Join with code" action.
  final String? initialCode;

  @override
  ConsumerState<JoinOrganizationPage> createState() =>
      _JoinOrganizationPageState();
}

class _JoinOrganizationPageState extends ConsumerState<JoinOrganizationPage> {
  final _controller = MobileScannerController();
  late final _codeController = TextEditingController(text: widget.initialCode);

  // A deep-linked code arrives pre-filled and ready to confirm — showing
  // the camera first would just make the user switch views manually.
  late bool _scanning = widget.initialCode == null;
  bool _redeeming = false;

  @override
  void dispose() {
    _controller.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// Fires repeatedly per-frame while a code stays in view, so the guard
  /// must be set and the camera stopped synchronously — before the first
  /// `await` — or one scan spawns many concurrent redeem calls.
  void _onDetect(BarcodeCapture capture) {
    if (_redeeming) {
      return;
    }
    final rawValue = capture.barcodes.firstOrNull?.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    _redeeming = true;
    _controller.stop();
    _redeem(rawValue.trim());
  }

  Future<void> _redeem(String code) async {
    setState(() => _redeeming = true);

    final result = await ref.read(redeemOrgJoinCodeUseCaseProvider).call(code);

    if (!mounted) {
      return;
    }

    result.fold(
      (f) {
        setState(() => _redeeming = false);
        context.showSnackBar(f.message, isError: true);
        if (_scanning) {
          _controller.start();
        }
      },
      (org) {
        ref.invalidate(myOrganizationsProvider);
        context.showSnackBar('Joined ${org.name}');
        context.go('/organizations/${org.id}/members');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join organization'),
        actions: [
          IconButton(
            icon: Icon(
              _scanning ? Icons.keyboard_outlined : Icons.qr_code_scanner,
            ),
            tooltip: _scanning ? 'Enter code manually' : 'Scan QR code',
            onPressed: _redeeming
                ? null
                : () => setState(() {
                    _scanning = !_scanning;
                    if (_scanning) {
                      _controller.start();
                    } else {
                      _controller.stop();
                    }
                  }),
          ),
        ],
      ),
      body: _scanning ? _buildScanner(context) : _buildManualEntry(context),
    );
  }

  Widget _buildScanner(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white70, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        if (_redeeming)
          Container(
            color: Colors.black45,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildManualEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Enter the join code your organization gave you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            enabled: !_redeeming,
            decoration: const InputDecoration(
              labelText: 'Join code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _codeController,
            builder: (context, _) => FilledButton(
              onPressed: _redeeming || _codeController.text.trim().isEmpty
                  ? null
                  : () => _redeem(_codeController.text.trim()),
              child: _redeeming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join'),
            ),
          ),
        ],
      ),
    );
  }
}
