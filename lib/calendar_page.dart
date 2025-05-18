import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('calendar_coming_soon'.tr(), textAlign: TextAlign.center),
    );
  }
}
