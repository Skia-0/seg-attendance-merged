import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'attendance_screen.dart';

class CohortScreen extends StatefulWidget {
  const CohortScreen({super.key});

  @override
  State<CohortScreen> createState() => _CohortScreenState();
}

class _CohortScreenState extends State<CohortScreen> {
  final _sessionTitleController = TextEditingController();
  bool _isLoading = true;
  bool _isStarting = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _cohorts = [];
  Map<String, dynamic>? _selectedCohort;

  @override
  void initState() {
    super.initState();
    _loadCohorts();
  }

  @override
  void dispose() {
    _sessionTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadCohorts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.get(
        '/sessions/cohorts',
        requiresAuth: true,
      );
      setState(() {
        _cohorts = List<Map<String, dynamic>>.from(response.data['cohorts']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cohorts. Check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _startSession() async {
    if (_selectedCohort == null) {
      setState(() => _errorMessage = 'Please select a cohort.');
      return;
    }

    if (_sessionTitleController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a session title.');
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.post(
        '/sessions/start',
        {
          'cohort_id': _selectedCohort!['cohort_id'],
          'title': _sessionTitleController.text.trim(),
        },
        requiresAuth: true,
      );

      final sessionId = response.data['session_id'];

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              sessionId: sessionId,
              sessionTitle: _sessionTitleController.text.trim(),
              cohortId: _selectedCohort!['cohort_id'],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to start session. A session may already be active for this cohort.';
        _isStarting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Manage Cohort'),
        backgroundColor: const Color(0xFF2C5F8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Start a Session',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C5F8A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a cohort and enter a session title to begin.',
                      style: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
                    ),
                    const SizedBox(height: 24),

                    // Cohort dropdown
                    const Text(
                      'Select Cohort',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A5568)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _selectedCohort,
                          hint: const Text('Choose a cohort...'),
                          isExpanded: true,
                          items: _cohorts.map((cohort) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: cohort,
                              child: Text(cohort['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedCohort = value);
                          },
                        ),
                      ),
                    ),

                    if (_selectedCohort != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C5F8A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedCohort!['name'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Min attendance: ${_selectedCohort!['min_attendance_percent']}%',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    TextField(
                      controller: _sessionTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Session Title',
                        hintText: 'e.g. Poultry Management - Week 3',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isStarting ? null : _startSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1baf7a),
                          foregroundColor: Colors.white,
                        ),
                        child: _isStarting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Start Session',
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