// form_dialog.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:easy_localization/easy_localization.dart';

class FormDialog extends StatefulWidget {
  final String initialPlaceDetails;
  final String initialTitle;
  final String initialUser;
  final String initialDescription;
  final String initialStartDate;
  final String initialEndDate;
  final Map<LatLng, String> savedLocations;
  final LatLng initialLocation;

  const FormDialog({
    super.key,
    this.initialPlaceDetails = '',
    this.initialTitle = '',
    this.initialUser = '',
    this.initialDescription = '',
    this.initialStartDate = '',
    this.initialEndDate = '',
    required this.savedLocations,
    required this.initialLocation,
  });

  @override
  FormDialogState createState() => FormDialogState();
}

class FormDialogState extends State<FormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _userController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  late final Map<LatLng,String> _savedLocations;
  LatLng _selectedLocation = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _userController.text = widget.initialUser;
    _titleController.text = widget.initialTitle;
    _descriptionController.text = widget.initialDescription;
    _startDateController.text = widget.initialStartDate;
    _endDateController.text = widget.initialEndDate;

    // Make sure the initial location is in the saved locations map
    _savedLocations = Map<LatLng, String>.from(widget.savedLocations);
    _savedLocations[widget.initialLocation] = widget.initialPlaceDetails;

    // Set the selected location to the initial location
    _selectedLocation = widget.initialLocation;
  }

  // ignore: use_build_context_synchronously
  Future<void> _selectDateTime(TextEditingController controller) async {
    if (!mounted) return;

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (!mounted) return;

    if (pickedDate != null) {
      // ignore: use_build_context_synchronously
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (!mounted) return;

      if (pickedTime != null) {
        final DateTime fullDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        controller.text = DateFormat('yyyy-MM-dd HH:mm').format(fullDateTime);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: DropdownButtonFormField<LatLng>(
              isExpanded: true,
              value: _selectedLocation,
              items: _savedLocations.entries.map((entry) {
                String displayText = entry.value.isNotEmpty
                    ? entry.value
                    : '${entry.key.latitude}, ${entry.key.longitude}';
                return DropdownMenuItem<LatLng>(
                  value: entry.key,
                  child: Text(displayText, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLocation = value!;
                });
              },
              decoration: InputDecoration(labelText: 'Selected Location'.tr()),
              validator: (value) {
                if (value == null) {
                  return 'Please select a location'.tr();
                }
                return null;
              },
            ),
          ),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title'.tr()),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title'.tr();
              }
              return null;
            },
          ),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Description'.tr()),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description'.tr();
              }
              return null;
            },
          ),
          TextFormField(
            controller: _startDateController,
            decoration: InputDecoration(
              labelText: 'Start Date and Time'.tr(),
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDateTime(_startDateController),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a start date and time'.tr();
              }
              return null;
            },
          ),
          TextFormField(
            controller: _endDateController,
            decoration: InputDecoration(
              labelText: 'End Date and Time'.tr(),
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDateTime(_endDateController),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an end date and time'.tr();
              }
              return null;
            },
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              String? nom = FirebaseAuth.instance.currentUser?.displayName;
              if (nom != null) {
                _userController.text = nom;
              }
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'location': "${_selectedLocation.latitude}, ${_selectedLocation.longitude}",
                  'user': _userController.text,
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                  'startDate': _startDateController.text,
                  'endDate': _endDateController.text,
                });
              }
            },
            child: Text('Submit'.tr()),
          ),
        ],
      ),
    );
  }
}

