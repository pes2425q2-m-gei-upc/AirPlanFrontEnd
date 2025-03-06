import 'package:flutter/material.dart';

void main() {
  runApp(MiApp());
}

class MiApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Sphere with Cross')),
        body: SphereWithCross(),
      ),
    );
  }
}

class SphereWithCross extends StatefulWidget {
  @override
  _SphereWithCrossState createState() => _SphereWithCrossState();
}

class _SphereWithCrossState extends State<SphereWithCross> {
  List<List<String>> _grid = List.generate(10, (_) => List.generate(10, (_) => ''));

  void _showForm() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter Details'),
          content: FormDialog(),
        );
      },
    );

    if (result != null) {
      setState(() {
        int x = int.parse(result['location']!.split(',')[0]);
        int y = int.parse(result['location']!.split(',')[1]);
        _grid[x][y] = 'X';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double gridSize = constraints.maxWidth / 10;
        return Stack(
          children: [
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                childAspectRatio: 1,
              ),
              itemCount: 100,
              itemBuilder: (context, index) {
                int x = index % 10;
                int y = index ~/ 10;
                return Container(
                  margin: EdgeInsets.all(1),
                  color: Colors.grey[300],
                  child: Center(
                    child: _grid[x][y] == 'X'
                        ? Icon(Icons.location_on, color: Colors.red)
                        : null,
                  ),
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: GestureDetector(
                onTap: _showForm,
                child: CustomPaint(
                  size: Size(100, 100),
                  painter: SphereWithCrossPainter(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class SphereWithCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw the sphere
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);

    final crossPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0;

    // Draw the vertical line of the cross
    canvas.drawLine(
      Offset(size.width / 2, size.height / 4),
      Offset(size.width / 2, 3 * size.height / 4),
      crossPaint,
    );

    // Draw the horizontal line of the cross
    canvas.drawLine(
      Offset(size.width / 4, size.height / 2),
      Offset(3 * size.width / 4, size.height / 2),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class FormDialog extends StatefulWidget {
  @override
  _FormDialogState createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _userController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _locationController,
            decoration: InputDecoration(labelText: 'Location (x,y)'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a location';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _userController,
            decoration: InputDecoration(labelText: 'User'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a user';
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
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop({
                  'location': _locationController.text,
                  'user': _userController.text,
                  'description': _descriptionController.text,
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