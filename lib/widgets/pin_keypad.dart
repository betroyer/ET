import 'package:flutter/material.dart';

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 72);
            }
            return Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: 72,
                height: 72,
                child: FilledButton.tonal(
                  onPressed: () {
                    if (key == '⌫') {
                      onBackspace();
                    } else {
                      onDigit(key);
                    }
                  },
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  child: Text(key),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
