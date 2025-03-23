//air_quality.dart
import 'package:flutter/material.dart';

enum AirQuality {
  excelent,
  bona,
  dolenta,
  pocSaludable,
  moltPocSaludable,
  perillosa,
}

enum Contaminant {
  SO2,
  PM10,
  PM2_5,
  NO2,
  O3,
  H2S,
  CO,
  C6H6,
}

class AirQualityData {
  late Contaminant contaminant;
  late double value;
  late String units;
  late AirQuality aqi;
  late DateTime lastDateHour;

  AirQualityData(this.contaminant, this.value, this.units, this.aqi, this.lastDateHour);
}

AirQuality calculateAQI(double concentration, Contaminant contaminant) {
  switch (contaminant) {
    case Contaminant.SO2:
      if (concentration <= 100) {return AirQuality.excelent;}
      else if (concentration <= 200) {return AirQuality.bona;}
      else if (concentration <= 350) {return AirQuality.dolenta;}
      else if (concentration <= 500) {return AirQuality.pocSaludable;}
      else if (concentration <= 750) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.PM10:
      if (concentration <= 20) {return AirQuality.excelent;}
      else if (concentration <= 40) {return AirQuality.bona;}
      else if (concentration <= 50) {return AirQuality.dolenta;}
      else if (concentration <= 100) {return AirQuality.pocSaludable;}
      else if (concentration <= 150) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.PM2_5:
      if (concentration <= 10) {return AirQuality.excelent;}
      else if (concentration <= 20) {return AirQuality.bona;}
      else if (concentration <= 25) {return AirQuality.dolenta;}
      else if (concentration <= 50) {return AirQuality.pocSaludable;}
      else if (concentration <= 75) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.NO2:
      if (concentration <= 40) {return AirQuality.excelent;}
      else if (concentration <= 90) {return AirQuality.bona;}
      else if (concentration <= 120) {return AirQuality.dolenta;}
      else if (concentration <= 230) {return AirQuality.pocSaludable;}
      else if (concentration <= 340) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.O3:
      if (concentration <= 50) {return AirQuality.excelent;}
      else if (concentration <= 100) {return AirQuality.bona;}
      else if (concentration <= 130) {return AirQuality.dolenta;}
      else if (concentration <= 240) {return AirQuality.pocSaludable;}
      else if (concentration <= 380) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.H2S:
      if (concentration <= 25) {return AirQuality.excelent;}
      else if (concentration <= 50) {return AirQuality.bona;}
      else if (concentration <= 100) {return AirQuality.dolenta;}
      else if (concentration <= 200) {return AirQuality.pocSaludable;}
      else if (concentration <= 500) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.CO:
      if (concentration <= 2) {return AirQuality.excelent;}
      else if (concentration <= 5) {return AirQuality.bona;}
      else if (concentration <= 10) {return AirQuality.dolenta;}
      else if (concentration <= 20) {return AirQuality.pocSaludable;}
      else if (concentration <= 50) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.C6H6:
      if (concentration <= 5) {return AirQuality.excelent;}
      else if (concentration <= 10) {return AirQuality.bona;}
      else if (concentration <= 20) {return AirQuality.dolenta;}
      else if (concentration <= 50) {return AirQuality.pocSaludable;}
      else if (concentration <= 100) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
  }
}

AirQualityData getLastAirQualityData(Map<String, dynamic> entry) {
  Contaminant contaminant = Contaminant.SO2;
  double valor = 0;
  String units = "";
  AirQuality aqi = AirQuality.excelent;
  int year = 0;
  int month = 0;
  int day = 0;
  int maxHour = 0;

  entry.forEach((key, value) {
    if (key == 'data') {
      year = int.parse(value.substring(0, 4));
      month = int.parse(value.substring(5, 7));
      day = int.parse(value.substring(8, 10));
    }
    if (key == 'contaminant') {
      switch (value) {
        case 'SO2':
          contaminant = Contaminant.SO2;
          break;
        case 'PM10':
          contaminant = Contaminant.PM10;
          break;
        case 'PM2.5':
          contaminant = Contaminant.PM2_5;
          break;
        case 'NO2':
          contaminant = Contaminant.NO2;
          break;
        case 'O3':
          contaminant = Contaminant.O3;
          break;
        case 'H2S':
          contaminant = Contaminant.H2S;
          break;
        case 'CO':
          contaminant = Contaminant.CO;
          break;
        case 'C6H6':
          contaminant = Contaminant.C6H6;
          break;
      }
    }
    if (key == 'unitats') {
      units = value;
    }
    if (key.startsWith('h')) {
      int hour = int.tryParse(key.substring(1)) ?? 0;
      if (hour > maxHour) {
        maxHour = hour;
        valor = double.parse(value);
      }
    }
  });

  aqi = calculateAQI(valor, contaminant);

  return AirQualityData(contaminant, valor, units, aqi, DateTime.utc(year,month,day,maxHour,0,0));
}

Color getColorForAirQuality(AirQuality aqi) {
  if (aqi == AirQuality.excelent) {
    return Colors.lightBlue;
  } else if (aqi == AirQuality.bona) {
    return Colors.green;
  } else if (aqi == AirQuality.dolenta) {
    return Colors.yellow;
  } else if (aqi == AirQuality.pocSaludable) {
    return Colors.red;
  } else if (aqi == AirQuality.moltPocSaludable) {
    return Colors.purple;
  }
  return Colors.deepPurple.shade900;
}

Contaminant parseContaminant(String contaminant) {
  switch (contaminant) {
    case 'SO2':
      return Contaminant.SO2;
    case 'PM10':
      return Contaminant.PM10;
    case 'PM2.5':
      return Contaminant.PM2_5;
    case 'NO2':
      return Contaminant.NO2;
    case 'O3':
      return Contaminant.O3;
    case 'H2S':
      return Contaminant.H2S;
    case 'CO':
      return Contaminant.CO;
    case 'C6H6':
      return Contaminant.C6H6;
    default:
      throw Exception('Unknown contaminant');
  }
}