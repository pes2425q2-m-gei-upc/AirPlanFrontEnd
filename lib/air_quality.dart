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
  so2,
  pm10,
  pm2_5,
  no2,
  o3,
  h2s,
  co,
  c6h6,
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
    case Contaminant.so2:
      if (concentration <= 100) {return AirQuality.excelent;}
      else if (concentration <= 200) {return AirQuality.bona;}
      else if (concentration <= 350) {return AirQuality.dolenta;}
      else if (concentration <= 500) {return AirQuality.pocSaludable;}
      else if (concentration <= 750) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.pm10:
      if (concentration <= 20) {return AirQuality.excelent;}
      else if (concentration <= 40) {return AirQuality.bona;}
      else if (concentration <= 50) {return AirQuality.dolenta;}
      else if (concentration <= 100) {return AirQuality.pocSaludable;}
      else if (concentration <= 150) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.pm2_5:
      if (concentration <= 10) {return AirQuality.excelent;}
      else if (concentration <= 20) {return AirQuality.bona;}
      else if (concentration <= 25) {return AirQuality.dolenta;}
      else if (concentration <= 50) {return AirQuality.pocSaludable;}
      else if (concentration <= 75) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.no2:
      if (concentration <= 40) {return AirQuality.excelent;}
      else if (concentration <= 90) {return AirQuality.bona;}
      else if (concentration <= 120) {return AirQuality.dolenta;}
      else if (concentration <= 230) {return AirQuality.pocSaludable;}
      else if (concentration <= 340) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.o3:
      if (concentration <= 50) {return AirQuality.excelent;}
      else if (concentration <= 100) {return AirQuality.bona;}
      else if (concentration <= 130) {return AirQuality.dolenta;}
      else if (concentration <= 240) {return AirQuality.pocSaludable;}
      else if (concentration <= 380) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.h2s:
      if (concentration <= 25) {return AirQuality.excelent;}
      else if (concentration <= 50) {return AirQuality.bona;}
      else if (concentration <= 100) {return AirQuality.dolenta;}
      else if (concentration <= 200) {return AirQuality.pocSaludable;}
      else if (concentration <= 500) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.co:
      if (concentration <= 2) {return AirQuality.excelent;}
      else if (concentration <= 5) {return AirQuality.bona;}
      else if (concentration <= 10) {return AirQuality.dolenta;}
      else if (concentration <= 20) {return AirQuality.pocSaludable;}
      else if (concentration <= 50) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
    case Contaminant.c6h6:
      if (concentration <= 5) {return AirQuality.excelent;}
      else if (concentration <= 10) {return AirQuality.bona;}
      else if (concentration <= 20) {return AirQuality.dolenta;}
      else if (concentration <= 50) {return AirQuality.pocSaludable;}
      else if (concentration <= 100) {return AirQuality.moltPocSaludable;}
      else {return AirQuality.perillosa;}
  }
}

AirQualityData getLastAirQualityData(Map<String, dynamic> entry) {
  Contaminant contaminant = Contaminant.so2;
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
          contaminant = Contaminant.so2;
          break;
        case 'PM10':
          contaminant = Contaminant.pm10;
          break;
        case 'PM2.5':
          contaminant = Contaminant.pm2_5;
          break;
        case 'NO2':
          contaminant = Contaminant.no2;
          break;
        case 'O3':
          contaminant = Contaminant.o3;
          break;
        case 'H2S':
          contaminant = Contaminant.h2s;
          break;
        case 'CO':
          contaminant = Contaminant.co;
          break;
        case 'C6H6':
          contaminant = Contaminant.c6h6;
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
      return Contaminant.so2;
    case 'PM10':
      return Contaminant.pm10;
    case 'PM2.5':
      return Contaminant.pm2_5;
    case 'NO2':
      return Contaminant.no2;
    case 'O3':
      return Contaminant.o3;
    case 'H2S':
      return Contaminant.h2s;
    case 'CO':
      return Contaminant.co;
    case 'C6H6':
      return Contaminant.c6h6;
    default:
      throw Exception('Unknown contaminant');
  }
}