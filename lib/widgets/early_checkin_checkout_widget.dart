import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/api_booking_service.dart';
import '../utils/app_theme.dart';

class EarlyCheckInCheckOutWidget extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onTimesSubmitted;

  const EarlyCheckInCheckOutWidget({
    Key? key,
    required this.booking,
    required this.onTimesSubmitted,
  }) : super(key: key);

  @override
  State<EarlyCheckInCheckOutWidget> createState() =>
      _EarlyCheckInCheckOutWidgetState();
}

class _EarlyCheckInCheckOutWidgetState extends State<EarlyCheckInCheckOutWidget> {
  late TimeOfDay? _actualCheckInTime;
  late TimeOfDay? _actualCheckOutTime;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _parseExistingTimes();
  }

  void _parseExistingTimes() {
    if (widget.booking.actualCheckInTime != null) {
      final parts = widget.booking.actualCheckInTime!.split(':');
      _actualCheckInTime =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      _actualCheckInTime = null;
    }

    if (widget.booking.actualCheckOutTime != null) {
      final parts = widget.booking.actualCheckOutTime!.split(':');
      _actualCheckOutTime =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } else {
      _actualCheckOutTime = null;
    }
  }

  String _calculateDuration(TimeOfDay? checkIn, TimeOfDay? checkOut) {
    if (checkIn == null || checkOut == null) return 'N/A';
    try {
      int startMinutes = checkIn.hour * 60 + checkIn.minute;
      int endMinutes = checkOut.hour * 60 + checkOut.minute;

      // Handle case where end time is next day
      if (endMinutes < startMinutes) {
        endMinutes += 24 * 60;
      }

      int durationMinutes = endMinutes - startMinutes;
      int hours = durationMinutes ~/ 60;
      int minutes = durationMinutes % 60;

      if (hours > 0 && minutes > 0) {
        return '$hours jam $minutes menit';
      } else if (hours > 0) {
        return '$hours jam';
      } else {
        return '$minutes menit';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    if (hours > 0 && remainder > 0) {
      return '$hours jam $remainder menit';
    }
    if (hours > 0) {
      return '$hours jam';
    }
    return '$remainder menit';
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn ? (_actualCheckInTime ?? TimeOfDay.now()) : (_actualCheckOutTime ?? TimeOfDay.now()),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _actualCheckInTime = picked;
        } else {
          _actualCheckOutTime = picked;
        }
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitTimes() async {
    if (_actualCheckInTime == null || _actualCheckOutTime == null) {
      setState(() {
        _errorMessage = 'Kedua waktu harus diisi';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final checkInStr =
          '${_actualCheckInTime!.hour.toString().padLeft(2, '0')}:${_actualCheckInTime!.minute.toString().padLeft(2, '0')}';
      final checkOutStr =
          '${_actualCheckOutTime!.hour.toString().padLeft(2, '0')}:${_actualCheckOutTime!.minute.toString().padLeft(2, '0')}';

      await ApiBookingService.submitCheckInCheckOut(
        bookingId: widget.booking.id,
        actualCheckInTime: checkInStr,
        actualCheckOutTime: checkOutStr,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Waktu check-in/check-out berhasil disimpan'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        widget.onTimesSubmitted();
        setState(() {
          _isExpanded = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal menyimpan waktu: $e';
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

  void _resetTimes() {
    setState(() {
      _actualCheckInTime = null;
      _actualCheckOutTime = null;
      _errorMessage = null;
      _isExpanded = false;
      _parseExistingTimes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActualTimes = _actualCheckInTime != null && _actualCheckOutTime != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(12),
        color: hasActualTimes ? AppColors.successGreenLight : Colors.transparent,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: AppColors.primaryRed,
                    size: 24,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check-in/Check-out Awal',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText,
                              ),
                        ),
                        const SizedBox(height: 4),
                        if (hasActualTimes)
                          Text(
                            '${_actualCheckInTime!.format(context)} - ${_actualCheckOutTime!.format(context)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.successGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                          )
                        else
                          Text(
                            'Atur waktu aktual check-in dan check-out',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.secondaryText,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.borderColor),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Check-in Time Picker
                  _buildTimePickerField(
                    label: 'Waktu Check-in Aktual',
                    time: _actualCheckInTime,
                    onTap: () => _selectTime(true),
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Check-out Time Picker
                  _buildTimePickerField(
                    label: 'Waktu Check-out Aktual',
                    time: _actualCheckOutTime,
                    onTap: () => _selectTime(false),
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Duration display
                  if (_actualCheckInTime != null && _actualCheckOutTime != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.successGreenLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Durasi Aktual:',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryText,
                                ),
                          ),
                          Text(
                              widget.booking.actualDurationMinutes != null
                              ? _formatMinutes(widget.booking.actualDurationMinutes!)
                              : _calculateDuration(_actualCheckInTime, _actualCheckOutTime),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.successGreen,
                                ),
                          ),
                        ],
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

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _resetTimes,
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_actualCheckInTime != null &&
                                  _actualCheckOutTime != null &&
                                  !_isLoading)
                              ? _submitTimes
                              : null,
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
                                  'Simpan',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: time != null ? AppColors.primaryRed : AppColors.borderColor,
                width: time != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.creamBackground,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time != null ? time.format(context) : 'Pilih waktu',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: time != null
                            ? AppColors.primaryText
                            : AppColors.secondaryText,
                        fontWeight: time != null ? FontWeight.w600 : null,
                      ),
                ),
                const Icon(
                  Icons.schedule,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
