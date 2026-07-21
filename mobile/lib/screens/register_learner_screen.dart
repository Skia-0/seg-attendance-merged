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

  List<Map<String, dynamic>> _cohorts = [];
  Map<String, dynamic>? _selectedCohort;

  String? _nfcUid;
  bool _fingerprintEnrolled = false;
  bool _isScanning = false;
  bool _isLoading = false;
  bool _isLoadingCohorts = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCohorts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    NfcService.stopReading();
    super.dispose();
  }

  Future<void> _loadCohorts() async {
    try {
      final response = await ApiService.get(
        '/sessions/cohorts',
        requiresAuth: true,
      );
      setState(() {
        _cohorts = List<Map<String, dynamic>>.from(
          response.data['cohorts'] ?? []);
        _isLoadingCohorts = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cohorts. Check your connection.';
        _isLoadingCohorts = false;
      });
    }
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
    final canCheck = await BiometricService.isAvailable();
    if (!canCheck) {
      _showFingerprintPopup(
        title: 'No Fingerprint Setup',
        message: 'Your device does not have fingerprints enrolled.\n'
            'Go to Settings > Security > Fingerprint to add one first.',
        success: false,
      );
      return;
    }

    // Show a clear popup before the system prompt
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Fingerprint Enrollment'),
        content: const Text('Place your enrolled finger on the sensor now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    final result = await BiometricService.authenticate(
      reason: 'Place your finger to enroll this learner',
    );

    _showFingerprintPopup(
      title: result ? 'Enrolled' : 'Not Recognised',
      message: result
          ? 'Fingerprint enrolled successfully.'
          : 'Finger not recognised. Make sure you use the same finger\n'
              'that is saved in your device Settings.',
      success: result,
    );

    setState(() => _fingerprintEnrolled = result);
  }

  void _showFingerprintPopup({
    required String title,
    required String message,
    required bool success,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_nameController.text.trim().isEmpty || _selectedCohort == null) {
      setState(() => _errorMessage = 'Name and Cohort selection are required.');
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
          'cohort_id': _selectedCohort!['cohort_id'],
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
            'cohort_id': _selectedCohort!['cohort_id'],
          },
          requiresAuth: true,
        );
      }

      setState(() {
        _successMessage = 'Learner registered! SEG ID: ${response.data['seg_id']}';
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
                'Fill in details, choose a cohort, scan NFC (optional), and enroll fingerprint (optional).',
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
              _isLoadingCohorts
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Select Cohort',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.group),
                      ),
                      value: _selectedCohort,
                      hint: const Text('Choose a cohort...'),
                      items: _cohorts.map((c) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: c,
                          child: Text(c['name'] ?? 'Unnamed'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCohort = val),
                    ),
              const SizedBox(height: 8),
              if (_selectedCohort != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0F7),
                    borderRadius: BorderRadius(8),
                  ),
                  child: Text(
                    'ID: ${_selectedCohort!['cohort_id'].toString().substring(0, 12)}...',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2C5F8A)),
                  ),
                ),
              const SizedBox(height: 24),
              // NFC Section (independent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _nfcUid != null ? Colors.green : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.nfc,
                          color: _nfcUid != null ? Colors.green : const Color(0xFF2C5F8A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _nfcUid != null ? 'NFC Card Scanned (optional)' : 'NFC Card (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _nfcUid != null ? Colors.green : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    if (_nfcUid != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'UID: ${_nfcUid!.substring(0, 12)}...',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
                      ),
                    ],
                    const SizedBox(height: 4),
                    const Text(
                      'You can register without scanning NFC.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isScanning ? null : _scanNfc,
                        icon: _isScanning
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.nfc),
                        label: Text(_isScanning ? 'Hold card to phone...' : (_nfcUid != null ? 'Scan Again' : 'Scan NFC Card')),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Fingerprint Section (independent)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _fingerprintEnrolled ? Colors.green : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.fingerprint,
                          color: _fingerprintEnrolled ? Colors.green : const Color(0xFF2C5F8A),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fingerprintEnrolled ? 'Fingerprint Enrolled (optional)' : 'Fingerprint (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _fingerprintEnrolled ? Colors.green : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Requires your phone to have a fingerprint saved in Settings > Security.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _fingerprintEnrolled ? null : _enrollFingerprint,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(_fingerprintEnrolled ? 'Enrolled' : 'Enroll Fingerprint'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
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
                      : const Text('Register Learner', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
