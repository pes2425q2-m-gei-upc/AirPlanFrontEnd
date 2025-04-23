// form_dialog.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class FormDialog extends StatefulWidget {
  final String initialPlaceDetails;
  final String initialTitle;
  final String initialUser;
  final String initialDescription;
  final String initialStartDate;
  final String initialEndDate;
  final Map<LatLng, String> savedLocations;
  final String initialLocation;

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
  LatLng _selectedLocation = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _userController.text = widget.initialUser;
    _titleController.text = widget.initialTitle;
    _descriptionController.text = widget.initialDescription;
    _startDateController.text = widget.initialStartDate;
    _endDateController.text = widget.initialEndDate;
    if (widget.savedLocations.isNotEmpty) {
      _selectedLocation = widget.savedLocations.keys.first;
    }
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      TimeOfDay? pickedTime = TimeOfDay.now();

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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: DropdownButtonFormField<LatLng>(
              value: _selectedLocation,
              items: widget.savedLocations.entries.map((entry) {
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
              decoration: InputDecoration(labelText: 'Selected Location'),
              validator: (value) {
                if (value == null) {
                  return 'Please select a location';
                }
                return null;
              },
            ),
          ),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Title'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a title';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Description'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _startDateController,
            decoration: InputDecoration(
              labelText: 'Start Date and Time',
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDateTime(_startDateController),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a start date and time';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _endDateController,
            decoration: InputDecoration(
              labelText: 'End Date and Time',
              suffixIcon: IconButton(
                icon: Icon(Icons.calendar_today),
                onPressed: () => _selectDateTime(_endDateController),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an end date and time';
              }
              return null;
            },
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              String? nom = FirebaseAuth.instance.currentUser?.displayName;
              print ('User1: $nom');
              if (nom != null) {
                _userController.text = nom;
                print ('User2: $nom');
              }
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'location': widget.initialLocation,
                  'user': _userController.text,
                  'title': _titleController.text,
                  'description': _descriptionController.text,
                  'startDate': _startDateController.text,
                  'endDate': _endDateController.text,
                });
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}