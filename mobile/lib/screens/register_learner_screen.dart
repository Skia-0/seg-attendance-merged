import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coordinator_provider.dart';
import '../services/api_service.dart';
import '../services/nfc_service.dart';
import '../services/biometric_service.dart';

class RegisterLearnerScreen extends StatefulWidget {
  const RegisterLearnerScreen({super.key});

  @override
  State<RegisterLearnerScreen> createState() => _RegisterLearnerScreenState();
}

class _RegisterLearnerScreenState extends State<RegisterLearnerScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cohortIdController = TextEditingController();

  String? _nfcUid;
  bool _fingerprintEnrolled = false;
  bool _isScanning = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cohortIdController.dispose();
    NfcService.stopReading();
    super.dispose();
  }

  Future<void> _scanNfc() async {
    final available = await NfcService.isAvailable();
    if (!available) {
      setState(() => _errorMessage = 'NFC is not available on this device.');
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    await NfcService.startReading(
      onRead: (uid) async {
        await NfcService.stopReading();
        setState(() {
          _nfcUid = uid;
          _isScanning = false;
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
          _isScanning = false;
        });
      },
    );
  }

  Future<void> _enrollFingerprint() async {
    final available = await BiometricService.isAvailable();
    if (!available) {
      setState(() => _errorMessage = 'Biometrics not available on this device.');
      return;
    }

    final result = await BiometricService.authenticate(
      reason: 'Ask the learner to place their finger to enroll',
    );

    setState(() {
      _fingerprintEnrolled = result;
      if (!result) _errorMessage = 'Fingerprint enrollment failed. Please try again.';
    });
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty || _cohortIdController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Name and Cohort ID are required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post(
        '/auth/learner/register',
        {
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'cohort_id': _cohortIdController.text.trim(),
          'nfc_uid': _nfcUid,
          'fingerprint_enrolled': _fingerprintEnrolled,
        },
        requiresAuth: true,
      );

      final learnerId = response.data['learner_id'];

      if (_nfcUid != null) {
        await ApiService.post(
          '/sessions/nfc/assign',
          {
            'nfc_uid': _nfcUid,
            'learner_id': learnerId,
            'cohort_id': _cohortIdController.text.trim(),
          },
          requiresAuth: true,
        );
      }

      setState(() {
        _successMessage =
            'Learner registered! SEG ID: ${response.data['seg_id']}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Registration failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Register Learner'),
        backgroundColor: const Color(0xFF2C5F8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Learner Registration',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5F8A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in details, scan NFC card, and enroll fingerprint.',
                style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _cohortIdController,
                decoration: const InputDecoration(
                  labelText: 'Cohort ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group),
                ),
              ),
              const SizedBox(height: 24),
              // NFC Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _nfcUid != null
                        ? Colors.green
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.nfc,
                          color: _nfcUid != null
                              ? Colors.green
                              : const Color(0xFF2C5F8A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _nfcUid != null
                              ? 'NFC Card Scanned'
                              : 'NFC Card',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _nfcUid != null
                                ? Colors.green
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    if (_nfcUid != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'UID: $_nfcUid',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF4A5568)),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isScanning ? null : _scanNfc,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.nfc),
                        label: Text(_isScanning
                            ? 'Hold card to phone...'
                            : _nfcUid != null
                                ? 'Scan Again'
                                : 'Scan NFC Card'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Fingerprint Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _fingerprintEnrolled
                        ? Colors.green
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: _fingerprintEnrolled
                              ? Colors.green
                              : const Color(0xFF2C5F8A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fingerprintEnrolled
                              ? 'Fingerprint Enrolled'
                              : 'Fingerprint',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _fingerprintEnrolled
                                ? Colors.green
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _enrollFingerprint,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(_fingerprintEnrolled
                            ? 'Re-enroll Fingerprint'
                            : 'Enroll Fingerprint'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5F8A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register Learner',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}