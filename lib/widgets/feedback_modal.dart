import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/api_booking_service.dart';
import '../utils/app_theme.dart';

class FeedbackModal extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onFeedbackSubmitted;

  const FeedbackModal({
    Key? key,
    required this.booking,
    required this.onFeedbackSubmitted,
  }) : super(key: key);

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

const _kComplaintTags = [
  'AC mati',
  'Proyektor tidak berfungsi',
  'Fasilitas tidak lengkap',
  'Ruangan kotor',
  'Koneksi internet buruk',
  'Kursi/meja kurang',
  'Kebisingan',
  'Lainnya',
];

class _FeedbackModalState extends State<FeedbackModal> {
  String? _selectedSatisfaction; // "satisfied" or "unsatisfied"
  final _reasonController = TextEditingController();
  final List<String> _selectedTags = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isReasonValid {
    if (_selectedSatisfaction == 'unsatisfied' && _selectedTags.isNotEmpty) return true;
    final text = _reasonController.text.trim();
    return text.length >= 10 && text.length <= 500;
  }

  bool get _canSubmit {
    return _selectedSatisfaction != null && _isReasonValid && !_isLoading;
  }

  String _buildReason() {
    final parts = <String>[];
    if (_selectedTags.isNotEmpty) {
      parts.add(_selectedTags.join(', '));
    }
    final text = _reasonController.text.trim();
    if (text.isNotEmpty) parts.add(text);
    return parts.join(' — ');
  }

  Future<void> _submitFeedback() async {
    if (!_canSubmit) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiBookingService.submitFeedback(
        bookingId: widget.booking.id,
        satisfaction: _selectedSatisfaction!,
        reason: _buildReason(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terima kasih atas umpan balik Anda!'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        widget.onFeedbackSubmitted();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal mengirim feedback: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                'Kepuasan Layanan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryRed,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Berikan penilaian layanan ruangan untuk booking ini',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Emoticon buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Satisfied button
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedSatisfaction = 'satisfied';
                              _selectedTags.clear();
                            });
                          },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedSatisfaction == 'satisfied'
                              ? AppColors.primaryRed
                              : AppColors.borderColor,
                          width: _selectedSatisfaction == 'satisfied' ? 3 : 2,
                        ),
                        color: _selectedSatisfaction == 'satisfied'
                            ? AppColors.successGreenLight
                            : Colors.transparent,
                      ),
                      child: const Center(
                        child: Text(
                          '😊',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                  // Unsatisfied button
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedSatisfaction = 'unsatisfied';
                            });
                          },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedSatisfaction == 'unsatisfied'
                              ? AppColors.errorRed
                              : AppColors.borderColor,
                          width: _selectedSatisfaction == 'unsatisfied' ? 3 : 2,
                        ),
                        color: _selectedSatisfaction == 'unsatisfied'
                            ? AppColors.errorRedLight
                            : Colors.transparent,
                      ),
                      child: const Center(
                        child: Text(
                          '😞',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // If satisfaction selected, show reason text area
              if (_selectedSatisfaction != null) ...[
                // Complaint tags (only for unsatisfied)
                if (_selectedSatisfaction == 'unsatisfied') ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kendala yang dialami:',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kComplaintTags.map((tag) {
                      final selected = _selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: selected,
                        onSelected: _isLoading
                            ? null
                            : (val) {
                                setState(() {
                                  if (val) {
                                    _selectedTags.add(tag);
                                  } else {
                                    _selectedTags.remove(tag);
                                  }
                                });
                              },
                        selectedColor: AppColors.errorRedLight,
                        checkmarkColor: AppColors.errorRed,
                        labelStyle: TextStyle(
                          color: selected ? AppColors.errorRed : AppColors.primaryText,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selected ? AppColors.errorRed : AppColors.borderColor,
                          width: selected ? 1.5 : 1,
                        ),
                        backgroundColor: AppColors.creamBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  _selectedSatisfaction == 'unsatisfied'
                      ? 'Catatan tambahan (opsional)'
                      : 'Jelaskan alasan Anda',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _reasonController,
                  enabled: !_isLoading,
                  maxLines: 4,
                  maxLength: 500,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: _selectedSatisfaction == 'unsatisfied'
                        ? 'Catatan tambahan (opsional)...'
                        : 'Minimal 10 karakter...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.primaryRed,
                        width: 2,
                      ),
                    ),
                    counterText: '${_reasonController.text.length}/500',
                    filled: true,
                    fillColor: AppColors.creamBackground,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),

                // Error message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorRedLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.errorRed,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Validation message
                if (!_isReasonValid && _reasonController.text.isNotEmpty &&
                    (_selectedSatisfaction != 'unsatisfied' || _selectedTags.isEmpty))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Tulisan harus antara 10-500 karakter',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.errorRed,
                          ),
                    ),
                  ),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canSubmit ? _submitFeedback : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          disabledBackgroundColor: AppColors.borderColor,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Kirim',
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              ] else
                ...[
                  Text(
                    'Pilih salah satu untuk lanjut',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Tutup'),
                  ),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
