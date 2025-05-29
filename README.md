# AirPlan

## Overview
AirPlan és una aplicació mòbil i web dissenyada per ajudar els usuaris a trobar o fer activitats a l'aire lliure. L'aplicació ofereix funcions com ara informació sobre la qualitat de l'aire i recomanacions d'activitats basades en la ubicació.

## Releases
- [Versió Web](https://airplanfrontend.onrender.com)
- [Aplicació Mòbil](https://github.com/pes2425q2-m-gei-upc/AirPlanFrontEnd/releases/tag/First_release)

## Features
- Consulta de la qualitat de l'aire en temps real.
- Recomanacions d’activitats a l’aire lliure segons la ubicació de l’usuari.
- Integració amb serveis de geolocalització.
- Compatible amb dispositius Android i Web.
- Interfície d’usuari intuïtiva i moderna.

## Tech Stack
- **Frontend Framework:** Flutter (Dart)
- **Plataformes:** Android, i Web
- **CMake:** Per a la configuració multiplataforma d'escriptori
- **Plugins:** firebase_auth, geolocator, rive, file_selector, etc.

## Getting Started

### Prerequisites
- Flutter SDK (https://flutter.dev/docs/get-started/install)
- Android Studio, Intellij IDEA o Visual Studio Code (opcional per desenvolupament)
- CMake (per compilació a Windows/Linux)
- Git

### Instal·lació

1. **Clona el repositori:**
   ```bash
   git clone https://github.com/pes2425q2-m-gei-upc/AirPlanFrontEnd.git
   cd AirPlanFrontEnd
   ```

2. **Instal·la les dependències de Flutter:**
   ```bash
   flutter pub get
   ```

3. **Executa a la plataforma desitjada:**

   - **Android o Web:**
     ```bash
     flutter run
     ```
     Després, selecciona el teu dispositiu amb les opcions que t'ofereix.

## Directory Structure
```
AirPlanFrontEnd/
├── android/
├── ios/
├── linux/
├── windows/
├── lib/
├── assets/
└── README.md
```

## Contributing
1. Fes un fork del projecte.
2. Crea una nova branca (`git checkout -b feature/novafuncio`).
3. Fes els teus canvis i commiteja'ls (`git commit -am 'Afegeix nova funció'`).
4. Fes un push a la branca (`git push origin feature/novafuncio`).
5. Obre una Pull Request.

## License
Aquest projecte està sota la llicència MIT. Consulta el fitxer `LICENSE` per a més informació.

## Authors
## Contributors

- Marwan Aliaoui: [hospola](https://github.com/hospola)
- Víctor Llorens: [Strifere](https://github.com/Strifere)
- Iker Santín: [iksaba](https://github.com/iksaba)
- Oscar Cerezo: [oscecon](https://github.com/oscecon)
- David González: [davigo2411](https://github.com/davigo2411)
- Jan Santos: [JanSanBas](https://github.com/JanSanBas)
