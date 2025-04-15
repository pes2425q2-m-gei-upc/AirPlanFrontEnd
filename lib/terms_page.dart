import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // Necesario para TapGestureRecognizer
import 'package:url_launcher/url_launcher.dart'; // Para abrir enlaces externos

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termes i Condicions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título principal
            Center(
              child: Text(
                'TERMES I CONDICIONS D\'ÚS',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 1. Acceptació (MODIFICADO)
            _buildSectionTitle(context, '1. Acceptació dels termes'),
            RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  const TextSpan(
                    text: 'En utilitzar l\'aplicació AirPlan ("l\'Aplicació"), acceptes automàticament aquests Termes i Condicions '
                        'd\'Ús, així com la nostra ',
                  ),
                  TextSpan(
                    text: 'Política de Privadesa',
                    style: TextStyle(
                      color: Colors.blue[800],
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {

                        // OPCIÓN 2: Si tienes una URL externa
                         launchUrl(Uri.parse('https://doc-hosting.flycricket.io/airplan-privacy-policy/fbec6272-8f1b-4550-a7db-94fce657b8f0/privacy')); // MODIFICA_AQUÍ con tu URL real
                      },
                  ),
                  const TextSpan(
                    text: '. Si no estàs d\'acord amb qualsevol part d\'aquests termes, '
                        'si us plau, no utilitzis el nostre servei.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Compte d'usuari (MODIFICADO para incluir eliminación de datos)
            _buildSectionTitle(context, '2. Compte d\'usuari'),
            const Text(
              '2.1. Per accedir a certes funcionalitats, hauràs de crear un compte amb email i contrasenya.\n\n'
                  '2.2. Ets l\'únic responsable de mantenir la confidencialitat de les teves credencials d\'accés.\n\n'
                  '2.3. Acceptes notificar-nos immediatament qualsevol accés no autoritzat al teu compte.\n\n'
                  '2.4. Pots eliminar el teu compte i dades en qualsevol moment enviant un correu a:',
            ),
            GestureDetector(
              onTap: () => launchUrl(Uri.parse('mailto:soporte@tudominio.com')), // MODIFICA_AQUÍ con tu email de soporte
              child: Text(
                'soporte@tudominio.com', // MODIFICA_AQUÍ
                style: TextStyle(
                  color: Colors.blue[800],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // [Resto de las secciones se mantienen igual...]
            // 3. Conducta acceptable
            _buildSectionTitle(context, '3. Conducta acceptable'),
            const Text(
              '3.1. Acceptes utilitzar l\'Aplicació únicament per a finalitats legals i d\'acord amb aquests termes.\n\n'
                  '3.2. No pots:\n'
                  '   • Utilitzar l\'Aplicació de manera fraudulenta o enganyosa\n'
                  '   • Violar drets de propietat intel·lectual\n'
                  '   • Pujar contingut maliciós o virus\n'
                  '   • Alterar el funcionament normal de l\'Aplicació',
            ),
            const SizedBox(height: 20),

            // 4. Propietat intel·lectual
            _buildSectionTitle(context, '4. Propietat intel·lectual'),
            const Text(
              '4.1. AirPlan i els seus logotips són marques registrades.\n\n'
                  '4.2. Tots els drets de propietat intel·lectual sobre els continguts i dissenys de l\'Aplicació pertanyen '
                  'exclusivament a nosaltres o als nostres llicenciadors.\n\n'
                  '4.3. No pots copiar, modificar o distribuir cap part de l\'Aplicació sense autorització per escrit.',
            ),
            const SizedBox(height: 20),

            // 5. Limitació de responsabilitat (MODIFICADO para mencionar Firebase)
            _buildSectionTitle(context, '5. Limitació de responsabilitat'),
            const Text(
              '5.1. L\'Aplicació es proporciona "tal qual" sense garanties de cap tipus. Utilitzem serveis de Firebase per a:\n'
                  '   • Autenticació d\'usuaris\n'
                  '   • Emmagatzematge de dades\n\n'
                  '5.2. No ens fem responsables de:\n'
                  '   • Danys indirectes, especials o consequencials\n'
                  '   • Pèrdua de dades o beneficis\n'
                  '   • Interrupcions del servei no degudes a la nostra negligència',
            ),
            const SizedBox(height: 20),

            // [Resto de secciones permanecen igual...]
            // 6. Modificacions
            _buildSectionTitle(context, '6. Modificacions'),
            const Text(
              'Ens reservem el dret de modificar aquests termes en qualsevol moment. Les versions actualitzades '
                  'entraran en vigor immediatament després de la seva publicació a l\'Aplicació. L\'ús continuat del '
                  'servei després dels canvis constituirà la teva acceptació dels nous termes.',
            ),
            const SizedBox(height: 20),

            // 7. Llei aplicable
            _buildSectionTitle(context, '7. Llei aplicable'),
            const Text(
              'Aquests termes es regeixen per les lleis d\'Espanya. Qualsevol disputa s\'haurà de resoldre als '
                  'tribunals competents de Barcelona, amb renúncia expressa a qualsevol altre fur.',
            ),
            const SizedBox(height: 30),

            // Fecha de última actualización
            Text(
              'Última actualització: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }
}