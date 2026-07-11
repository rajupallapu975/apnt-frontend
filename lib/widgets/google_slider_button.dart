import 'package:flutter/material.dart';

class GoogleSliderButton extends StatefulWidget {
  final VoidCallback onAction;
  final String label;

  const GoogleSliderButton({
    super.key,
    required this.onAction,
    this.label = 'Slide to sign in with Google',
  });

  @override
  GoogleSliderButtonState createState() =>
      GoogleSliderButtonState();
}

class GoogleSliderButtonState extends State<GoogleSliderButton> {
  double _position = 0;
  final double _handleSize = 56;
  bool _locked = false;

  void reset() {
    setState(() {
      _position = 0;
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxSlide =
            constraints.maxWidth - _handleSize - 16;

        return Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            boxShadow: const [
              BoxShadow(
                blurRadius: 12,
                color: Colors.black12,
              ),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Positioned(
                left: _position + 8,
                top: 8,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    if (_locked) return;
                    setState(() {
                      _position += d.delta.dx;
                      _position = _position.clamp(0, maxSlide);
                    });
                  },
                  onHorizontalDragEnd: (_) {
                    if (_position > maxSlide * 0.7) {
                      setState(() {
                        _position = maxSlide;
                        _locked = true;
                      });
                      widget.onAction();
                    } else {
                      reset();
                    }
                  },
                  child: Container(
                    width: _handleSize,
                    height: _handleSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/google_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
