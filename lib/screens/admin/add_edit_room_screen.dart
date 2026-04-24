import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/room_model.dart';
import '../../providers/room_provider.dart';
import '../../services/api_room_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../core/gen/assets.gen.dart';

class AddEditRoomScreen extends StatefulWidget {
  final RoomModel? room;
  
  const AddEditRoomScreen({Key? key, this.room}) : super(key: key);

  @override
  State<AddEditRoomScreen> createState() => _AddEditRoomScreenState();
}

class _AddEditRoomScreenState extends State<AddEditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _capacityController;
  late TextEditingController _floorController;
  late TextEditingController _buildingController;
  late TextEditingController _contactNumberController;
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  
  String _selectedClass = 'Meeting Room';
  bool _isAvailable = true;
  bool _isLoading = false;
  
  final List<String> _roomClasses = [
    'Meeting Room',
    'Conference Room',
    'Class Room',
    'Lecture Hall',
    'Training Room',
    'Board Room',
    'Study Room',
    'Lab',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.room?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.room?.description ?? '');
    _cityController = TextEditingController(text: widget.room?.city ?? '');
    _addressController =
        TextEditingController(text: widget.room?.location ?? '');
    _capacityController =
        TextEditingController(text: widget.room?.maxGuests.toString() ?? '');
    _floorController = TextEditingController(text: widget.room?.floor ?? '');
    _buildingController = TextEditingController(text: widget.room?.building ?? '');
    _contactNumberController = TextEditingController(text: widget.room?.contactNumber ?? '');
    
    if (widget.room != null) {
      _selectedClass = widget.room!.roomClass;
      _isAvailable = widget.room!.isAvailable;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _capacityController.dispose();
    _floorController.dispose();
    _buildingController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        Navigator.pop(context); // Close modal
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xBF170F0F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Choose Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // Camera option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primaryRed,
                ),
              ),
              title: const Text(
                'Take Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            
            const SizedBox(height: 10),
            
            // Gallery option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppColors.primaryRed,
                ),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Image
        Positioned.fill(
          child: Image(
            image: Assets.images.homeBg.provider(),
            fit: BoxFit.cover,
          ),
        ),
        
        // Content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              widget.room == null ? 'Add New Room' : 'Edit Room',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Image Picker Card
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: Container(
                    height: 200,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xBF170F0F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFAF0406),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : widget.room?.imageUrls.isNotEmpty == true
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  widget.room!.imageUrls.first,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildImagePlaceholder(),
                                ),
                              )
                            : _buildImagePlaceholder(),
                  ),
                ),
            CustomTextField(
              controller: _nameController,
              labelText: 'Room Name',
              hintText: 'e.g., Conference Room A',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter room name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _descriptionController,
              labelText: 'Description',
              hintText: 'Room description',
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: _selectedClass,
              decoration: const InputDecoration(
                labelText: 'Room Class',
                border: OutlineInputBorder(),
              ),
              items: _roomClasses.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedClass = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _capacityController,
              labelText: 'Capacity (persons)',
              hintText: 'e.g., 10',
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter capacity';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _buildingController,
              labelText: 'Building (Optional)',
              hintText: 'e.g., Building A',
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _floorController,
              labelText: 'Floor (Optional)',
              hintText: 'e.g., 3rd Floor',
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _cityController,
              labelText: 'City',
              hintText: 'e.g., Jakarta',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter city';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            CustomTextField(
              controller: _addressController,
              labelText: 'Address / Location',
              hintText: 'Full address',
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _contactNumberController,
              labelText: 'Contact Number',
              hintText: 'e.g., 021-1234567',
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter contact number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: const Color(0xBF170F0F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFAF0406), width: 1),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Available for Booking',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isAvailable ? 'Room is available' : 'Room is not available',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                value: _isAvailable,
                onChanged: (bool value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
                activeColor: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 24),
            
            CustomButton(
              onPressed: _isLoading ? () {} : _saveRoom,
              text: _isLoading
                  ? 'Saving...'
                  : (widget.room == null ? 'Add Room' : 'Update Room'),
            ),
          ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 60,
            color: AppColors.primaryRed.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap to add room image',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Camera or Gallery',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _saveRoom() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final roomProvider = Provider.of<RoomProvider>(context, listen: false);

      final roomData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'roomClass': _selectedClass,
        'maxGuests': int.parse(_capacityController.text.trim()),
        'city': _cityController.text.trim(),
        'location': _addressController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'isAvailable': _isAvailable,
        'floor': _floorController.text.trim().isEmpty
            ? null
            : _floorController.text.trim(),
        'building': _buildingController.text.trim().isEmpty
            ? null
            : _buildingController.text.trim(),
      };

      if (widget.room == null) {
        // Create room first, then upload image if selected
        final newRoom = await roomProvider.addRoom(roomData);
        if (_selectedImage != null) {
          await ApiRoomService.uploadImage(newRoom.id, _selectedImage!);
        }
      } else {
        // Update room data
        await roomProvider.updateRoom(widget.room!.id, roomData);
        // Upload new image if one was selected
        if (_selectedImage != null) {
          await ApiRoomService.uploadImage(widget.room!.id, _selectedImage!);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.room == null
                ? 'Room added successfully'
                : 'Room updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
