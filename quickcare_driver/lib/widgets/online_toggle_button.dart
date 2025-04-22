import 'package:flutter/material.dart';
import 'package:quickcare_driver/utilities/driver_status_manager.dart';

class OnlineToggleButton extends StatefulWidget {
  final Function(bool) onStatusChanged;
  final bool initialStatus;

  const OnlineToggleButton({
    Key? key,
    required this.onStatusChanged,
    this.initialStatus = false,
  }) : super(key: key);

  @override
  State<OnlineToggleButton> createState() => _OnlineToggleButtonState();
}

class _OnlineToggleButtonState extends State<OnlineToggleButton> {
  bool _isOnline = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.initialStatus;
  }

  Future<void> _toggleStatus() async {
    setState(() => _isLoading = true);

    bool success = await DriverStatusManager.toggleOnlineStatus(!_isOnline);

    if (success) {
      setState(() {
        _isOnline = !_isOnline;
        _isLoading = false;
      });

      widget.onStatusChanged(_isOnline);
    } else {
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please check location permissions.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _isOnline ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isOnline ? Colors.green : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
            _isLoading
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _isOnline ? Colors.green : Colors.grey[700],
              ),
            )
                : Switch(
              value: _isOnline,
              onChanged: (_) => _toggleStatus(),
              activeColor: Colors.green,
              inactiveThumbColor: Colors.grey[400],
              activeTrackColor: Colors.green.withOpacity(0.5),
              inactiveTrackColor: Colors.grey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
