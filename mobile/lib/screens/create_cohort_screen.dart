import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/coordinator_provider.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class CreateCohortScreen extends StatefulWidget {
  const CreateCohortScreen({super.key});

  @override
  State<CreateCohortScreen> createState() => _CreateCohortScreenState();
}

class _CreateCohortScreenState extends State<CreateCohortScreen> {
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 90)),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty || _startDate == null || _endDate == null) {
      setState(() => _errorMessage = 'Name and both dates are required.');
      return;
    }

    final hubId = Provider.of<CoordinatorProvider>(context, listen: false).hubId;
    if (hubId == null || hubId.isEmpty) {
      setState(() => _errorMessage = 'Hub not found. Please log in again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await ApiService.post(
        '/sessions/cohort/create',
        {
          'name': _nameController.text.trim(),
          'start_date': _startDate!.toIso8601String(),
          'end_date': _endDate!.toIso8601String(),
          'hub_id': hubId,
        },
        requiresAuth: true,
      );

      setState(() {
        _successMessage = 'Cohort created! ID: ${response.data['cohort_id']}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create cohort. Check your connection.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final coordinator = Provider.of<CoordinatorProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Create Cohort'),
        backgroundColor: const Color(0xFF2C5F8A),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Cohort',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5F8A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hub: ${coordinator.hubId ?? 'Not set'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Cohort Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.group_add),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickStart,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_startDate == null ? 'Start Date' : _startDate!.toLocal().toString().split(' ')[0]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickEnd,
                      icon: const Icon(Icons.event),
                      label: Text(_endDate == null ? 'End Date' : _endDate!.toLocal().toString().split(' ')[0]),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
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
                      Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700))),
                    ],
                  ),
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_successMessage!, style: const TextStyle(color: Colors.green)),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1baf7a),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Cohort'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
