import 'dart:async';

import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/api_booking_service.dart';
import '../utils/app_theme.dart';
import '../core/gen/assets.gen.dart';

class FeedbackModal extends StatefulWidget {
  final BookingModel booking;
  final List<String> roomAmenities;
  final VoidCallback onFeedbackSubmitted;
  final Duration? autoSkipAfter;

  const FeedbackModal({
    Key? key,
    required this.booking,
    this.roomAmenities = const [],
    required this.onFeedbackSubmitted,
    this.autoSkipAfter,
  }) : super(key: key);

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

const _kComplaintTagSuffix = ' rusak';

List<String> buildComplaintTagsFromAmenities(List<String> amenities) {
  final tags = <String>[];
  final seen = <String>{};

  for (final amenity in amenities) {
    final normalized = amenity.trim();
    if (normalized.isEmpty) continue;

    final lower = normalized.toLowerCase();
    if (seen.contains(lower)) continue;
    seen.add(lower);

    if (lower.endsWith(_kComplaintTagSuffix.trim())) {
      tags.add(normalized);
    } else {
      tags.add('$normalized$_kComplaintTagSuffix');
    }
  }

  return tags;
}

class _FeedbackModalState extends State<FeedbackModal> {
  String? _selectedSatisfaction; // "satisfied" or "unsatisfied"
  final List<String> _selectedTags = [];
  final TextEditingController _otherComplaintController =
      TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showApology = false;
  bool _showThankYou = false;
  Timer? _autoSkipTimer;

  @override
  void initState() {
    super.initState();
    _startAutoSkipTimer();
  }

  void _startAutoSkipTimer() {
    final autoSkipAfter = widget.autoSkipAfter;
    if (autoSkipAfter == null) {
      return;
    }

    _autoSkipTimer = Timer(autoSkipAfter, () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    });
  }

  void _cancelAutoSkipTimer() {
    _autoSkipTimer?.cancel();
    _autoSkipTimer = null;
  }

  void _startAutoClose() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  bool get _isReasonValid {
    if (_selectedSatisfaction == 'unsatisfied') {
      return _selectedTags.isNotEmpty ||
          _otherComplaintController.text.trim().isNotEmpty;
    }
    return true;
  }

  bool get _canSubmit {
    return _selectedSatisfaction != null && _isReasonValid && !_isLoading;
  }

  List<String> get _complaintTags =>
      buildComplaintTagsFromAmenities(widget.roomAmenities);

  String _buildReason() {
    if (_selectedSatisfaction == 'unsatisfied') {
      final parts = <String>[];
      if (_selectedTags.isNotEmpty) {
        parts.add(_selectedTags.join(', '));
      }
      final other = _otherComplaintController.text.trim();
      if (other.isNotEmpty) {
        parts.add('Lainnya: $other');
      }
      return 'Komplain: ${parts.join(' | ')}';
    }
    return 'Puas dengan layanan.';
  }

  Future<void> _submitFeedback({required bool keepOpen}) async {
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
        complaintItems: List<String>.from(_selectedTags),
        complaintOther: _otherComplaintController.text.trim().isEmpty
            ? null
            : _otherComplaintController.text.trim(),
      );

      if (mounted) {
        widget.onFeedbackSubmitted();
        _cancelAutoSkipTimer();
        if (keepOpen) {
          setState(() {
            _showApology = true;
          });
        } else {
          setState(() {
            _showThankYou = true;
          });
          _startAutoClose();
        }
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
  void dispose() {
    _cancelAutoSkipTimer();
    _otherComplaintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show dedicated thank-you screen
    if (_showThankYou) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Assets.images.puas.image(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Terima Kasih!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Kami senang melayani Anda. Terima kasih atas penilaian positif Anda. '
                'Masukan Anda sangat berharga bagi kami untuk terus meningkatkan pelayanan.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
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
                      fontSize: 30,
                      color: AppColors.primaryText,
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

              // Image buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedSatisfaction = 'satisfied';
                              _selectedTags.clear();
                            });
                            _submitFeedback(keepOpen: false);
                          },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedSatisfaction == 'satisfied'
                                  ? AppColors.successGreen
                                  : AppColors.borderColor,
                              width:
                                  _selectedSatisfaction == 'satisfied' ? 3 : 2,
                            ),
                            color: _selectedSatisfaction == 'satisfied'
                                ? AppColors.successGreenLight
                                : Colors.transparent,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Assets.images.puas.image(
                              width: 165,
                              height: 165,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Puas',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedSatisfaction = 'unsatisfied';
                              _showApology = false;
                            });
                          },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedSatisfaction == 'unsatisfied'
                                  ? AppColors.errorRed
                                  : AppColors.borderColor,
                              width: _selectedSatisfaction == 'unsatisfied'
                                  ? 3
                                  : 2,
                            ),
                            color: _selectedSatisfaction == 'unsatisfied'
                                ? AppColors.errorRedLight
                                : Colors.transparent,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Assets.images.kurangPuas.image(
                              width: 165,
                              height: 165,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak Puas',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.primaryText,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // If satisfaction selected, show reason text area
              if (_selectedSatisfaction != null) ...[
                // Complaint tags (only for unsatisfied)
                if (_selectedSatisfaction == 'unsatisfied' &&
                    !_showApology) ...[
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
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih fasilitas yang rusak, lalu tambahkan opsi lainnya jika perlu.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _complaintTags.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ruangan ini belum memiliki fasilitas terdaftar.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _complaintTags.map((tag) {
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
                          color: selected
                              ? AppColors.errorRed
                              : AppColors.primaryText,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selected
                              ? AppColors.errorRed
                              : AppColors.borderColor,
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
                  TextField(
                    controller: _otherComplaintController,
                    enabled: !_isLoading,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Lainnya',
                      hintText: 'Tulis kendala manual jika tidak ada di daftar',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primaryRed, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                if (_selectedSatisfaction == 'unsatisfied' && _showApology) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.creamBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Text(
                      'Mohon maaf atas ketidaknyamanan yang Anda alami. '
                      'Kami akan menindaklanjuti keluhan ini secepatnya.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

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
                if (!_isReasonValid && _selectedSatisfaction == 'unsatisfied')
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Pilih minimal satu kendala',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.errorRed,
                          ),
                    ),
                  ),

                // Actions
                if (_selectedSatisfaction == 'unsatisfied')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading || _showApology
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showApology
                              ? () => Navigator.of(context).pop(true)
                              : (_canSubmit
                                  ? () => _submitFeedback(keepOpen: true)
                                  : null),
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
                              : Text(
                                  _showApology ? 'Tutup' : 'Kirim',
                                  style: const TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
              ] else ...[
                Text(
                  'Pilih salah satu untuk lanjut',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                        fontStyle: FontStyle.italic,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(true),
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
