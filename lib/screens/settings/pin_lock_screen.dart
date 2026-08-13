import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/pin_keypad.dart';

enum PinMode { unlock, setup }

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key, this.mode = PinMode.unlock});

  final PinMode mode;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  String? _firstPin;
  String? _error;

  int get _targetLength => 4;

  @override
  Widget build(BuildContext context) {
    final isSetup = widget.mode == PinMode.setup;
    final confirming = isSetup && _firstPin != null;

    return Scaffold(
      appBar: isSetup ? AppBar(title: const Text('Set PIN')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              if (!isSetup) ...[
                const AppLogo(size: 88),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
              ] else
                Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                confirming
                    ? 'Confirm your PIN'
                    : isSetup
                        ? 'Create a 4-digit PIN'
                        : 'Enter PIN',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_targetLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              PinKeypad(
                onDigit: (d) async {
                  if (_pin.length >= _targetLength) return;
                  setState(() {
                    _pin += d;
                    _error = null;
                  });
                  if (_pin.length == _targetLength) {
                    await _submit();
                  }
                },
                onBackspace: () {
                  if (_pin.isEmpty) return;
                  setState(() => _pin = _pin.substring(0, _pin.length - 1));
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (widget.mode == PinMode.setup) {
      if (_firstPin == null) {
        setState(() {
          _firstPin = _pin;
          _pin = '';
        });
        return;
      }
      if (_firstPin != _pin) {
        setState(() {
          _error = 'PINs do not match';
          _firstPin = null;
          _pin = '';
        });
        return;
      }
      if (mounted) Navigator.pop(context, _pin);
      return;
    }

    final ok = await context.read<SettingsProvider>().unlock(_pin);
    if (!ok) {
      setState(() {
        _error = 'Incorrect PIN';
        _pin = '';
      });
    }
  }
}
