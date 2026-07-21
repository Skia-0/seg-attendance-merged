import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/biometric_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String sessionTitle;
  final String cohortId;

  const AttendanceScreen({
    super.key,
    required this.sessionId,
    required this.sessionTitle,
    required this.cohortId,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _checkinOpen = false;
  bool _checkoutOpen = false;
  bool _isProcessing = false;
  bool _isNfcScanning = false;
  String? _statusMessage;
  bool _statusSuccess = false;
  List<Map<String, dynamic>> _attendance = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void dispose() {
    NfcService.stopReading();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    try {
      final response = await ApiService.get(
        '/sessions/attendance/${widget.sessionId}',
        requiresAuth: true,
      );
      setState(() {
        _attendance = List<Map<String, dynamic>>.from(
            response.data['attendance']);
      });
    } catch (e) {
      // silent fail
    }
  }

  Future<void> _openCheckin() async {
    setState(() => _isProcessing = true);
    try {
      await ApiService.patch(
        '/sessions/checkin/open/${widget.sessionId}',
        {},
        requiresAuth: true,
      );
      setState(() {
        _checkinOpen = true;
        _checkoutOpen = false;
        _isProcessing = false;
      });
      _startNfcScan();
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _openCheckout() async {
    setState(() => _isProcessing = true);
    try {
      await ApiService.patch(
        '/sessions/checkout/open/${widget.sessionId}',
        {},
        requiresAuth: true,
      );
      setState(() {
        _checkinOpen = false;
        _checkoutOpen = true;
        _isProcessing = false;
      });
      _startNfcScan();
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _endSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session'),
        content: const Text('Are you sure you want to end this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await NfcService.stopReading();
      await ApiService.patch(
        '/sessions/end/${widget.sessionId}',
        {},
        requiresAuth: true,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // handle error
    }
  }

  Future<void> _startNfcScan() async {
    final nfcAvailable = await NfcService.isAvailable();

    if (!nfcAvailable) {
      _showStatus('NFC not available — use fingerprint instead.', false);
      return;
    }

    setState(() => _isNfcScanning = true);

    await NfcService.startReading(
      onRead: (uid) async {
        await NfcService.stopReading();
        setState(() => _isNfcScanning = false);
        await _processNfcUid(uid);
        if (_checkinOpen || _checkoutOpen) {
          await Future.delayed(const Duration(seconds: 2));
          _startNfcScan();
        }
      },
      onError: (error) {
        setState(() => _isNfcScanning = false);
        _showStatus(error, false);
      },
    );
  }

  Future<void> _processNfcUid(String uid) async {
    try {
      final lookupResponse = await ApiService.get(
        '/sessions/nfc/lookup/$uid',
        requiresAuth: true,
      );

      final learnerId = lookupResponse.data['learner_id'];
      final fullName = lookupResponse.data['full_name'];

      await _submitAttendance(learnerId, fullName, 'nfc');
    } catch (e) {
      _showStatus('Card not recognised. Please register this card.', false);
    }
  }

  Future<void> _fingerprintScan() async {
    final available = await BiometricService.isAvailable();
    if (!available) {
      _showStatus('Biometrics not available on this device.', false);
      return;
    }

    final verified = await BiometricService.authenticate(
      reason: 'Learner: place your finger to mark attendance',
    );

    if (!verified) {
      _showStatus('Fingerprint not recognised. Please try again.', false);
      return;
    }

    _showLearnerSelector();
  }

  Future<void> _showLearnerSelector() async {
    final learnerId = await showDialog<String>(
      context: context,
      builder: (ctx) => _LearnerSelectorDialog(cohortId: widget.cohortId),
    );

    if (learnerId != null) {
      await _submitAttendance(learnerId, '', 'fingerprint');
    }
  }

  Future<void> _submitAttendance(
      String learnerId, String fullName, String method) async {
    try {
      if (_checkinOpen) {
        final response = await ApiService.post(
          '/sessions/checkin',
          {
            'session_id': widget.sessionId,
            'learner_id': learnerId,
            'verification_method': method,
          },
          requiresAuth: true,
        );
        _showStatus(
            '✓ ${response.data['seg_id']} checked in via $method', true);
      } else if (_checkoutOpen) {
        final response = await ApiService.post(
          '/sessions/checkout',
          {
            'session_id': widget.sessionId,
            'learner_id': learnerId,
          },
          requiresAuth: true,
        );
        _showStatus(
            '✓ ${response.data['seg_id']} checked out via $method', true);
      }
      await _loadAttendance();
    } catch (e) {
      _showStatus('Already recorded or error occurred.', false);
    }
  }

  void _showStatus(String message, bool success) {
    setState(() {
      _statusMessage = message;
      _statusSuccess = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int completed =
        _attendance.where((r) => r['is_complete'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.sessionTitle),
        backgroundColor: const Color(0xFF2C5F8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: _checkinOpen
                  ? const Color(0xFF2C5F8A)
                  : _checkoutOpen
                      ? const Color(0xFF1baf7a)
                      : Colors.grey.shade400,
              child: Text(
                _checkinOpen
                    ? '✓ Check-in open — tap card or use fingerprint'
                    : _checkoutOpen
                        ? '✓ Check-out open — tap card or use fingerprint'
                        : 'Session not active — open check-in to begin',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            if (_statusMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: _statusSuccess
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Text(
                  _statusMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _statusSuccess
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard('Checked In',
                        '${_attendance.length}', const Color(0xFF2C5F8A)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                        'Completed', '$completed', const Color(0xFF1baf7a)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _openCheckin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C5F8A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Open Check-in'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _openCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1baf7a),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Open Check-out'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (_checkinOpen || _checkoutOpen)
                          ? _fingerprintScan
                          : null,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Fingerprint'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _endSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('End Session'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_isNfcScanning)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nfc, color: Color(0xFF2C5F8A)),
                    SizedBox(width: 8),
                    Text('Waiting for NFC card...',
                        style: TextStyle(color: Color(0xFF2C5F8A))),
                  ],
                ),
              ),
            Expanded(
              child: _attendance.isEmpty
                  ? const Center(
                      child: Text('No attendance records yet.',
                          style: TextStyle(color: Color(0xFF4A5568))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _attendance.length,
                      itemBuilder: (context, index) {
                        final record = _attendance[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: record['is_complete'] == true
                                  ? Colors.green
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                record['is_complete'] == true
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: record['is_complete'] == true
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      record['full_name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      record['seg_id'],
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4A5568)),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    record['checked_in_at'] != null
                                        ? 'In: ${record['checked_in_at'].toString().split('T')[1].substring(0, 8)}'
                                        : '--',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    record['checked_out_at'] != null
                                        ? 'Out: ${record['checked_out_at'].toString().split('T')[1].substring(0, 8)}'
                                        : '--',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
        ],
      ),
    );
  }
}

class _LearnerSelectorDialog extends StatefulWidget {
  final String cohortId;
  const _LearnerSelectorDialog({required this.cohortId});

  @override
  State<_LearnerSelectorDialog> createState() => _LearnerSelectorDialogState();
}

class _LearnerSelectorDialogState extends State<_LearnerSelectorDialog> {
  List<Map<String, dynamic>> _learners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLearners();
  }

  Future<void> _loadLearners() async {
    try {
      final response = await ApiService.get(
        '/sessions/cohort/${widget.cohortId}/learners',
        requiresAuth: true,
      );
      setState(() {
        _learners = List<Map<String, dynamic>>.from(
            response.data['learners'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Learner'),
      content: _isLoading
          ? const CircularProgressIndicator()
          : SizedBox(
              width: double.maxFinite,
              child: _learners.isEmpty
                  ? const Text('No learners found.')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _learners.length,
                      itemBuilder: (ctx, i) {
                        final learner = _learners[i];
                        return ListTile(
                          title: Text(learner['full_name'] ?? ''),
                          subtitle: Text(learner['seg_id'] ?? ''),
                          onTap: () =>
                              Navigator.pop(context, learner['learner_id']),
                        );
                      },
                    ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}