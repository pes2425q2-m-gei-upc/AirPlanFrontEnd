import 'package:flutter/material.dart';

class FormDialog extends StatefulWidget {
  final String initialLocation;
  final String initialTitle;
  final String initialUser;
  final String initialDescription;

  const FormDialog({super.key, 
    required this.initialLocation,
    required this.initialTitle,
    required this.initialUser,
    required this.initialDescription,
  });

  @override
  _FormDialogState createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  late TextEditingController _locationController;
  late TextEditingController _titleController;
  late TextEditingController _userController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.initialLocation);
    _titleController = TextEditingController(text: widget.initialTitle);
    _userController = TextEditingController(text: widget.initialUser);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  void dispose() {
    _locationController.dispose();
    _titleController.dispose();
    _userController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Detalls de l\'activitat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _locationController,
            decoration: InputDecoration(labelText: 'Ubicació (x,y)'),
            readOnly: true,
          ),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: 'Títol'),
          ),
          TextField(
            controller: _userController,
            decoration: InputDecoration(labelText: 'Usuari creador'),
          ),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Descripció'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel·lar'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop({
              'location': _locationController.text,
              'title': _titleController.text,
              'user': _userController.text,
              'description': _descriptionController.text,
            });
          },
          child: Text('Guardar'),
        ),
      ],
    );
  }
}
