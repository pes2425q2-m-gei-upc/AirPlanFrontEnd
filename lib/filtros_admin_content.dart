import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert'; // For jsonDecode and jsonEncode
import 'package:http/http.dart' as http; // HTTP package
import 'package:airplan/services/api_config.dart'; // Import ApiConfig
import 'package:easy_localization/easy_localization.dart';

// Model for individual attribute settings in the UI
class AttributeSettingUIModel {
  final String name;
  bool isEnabled;
  double threshold;
  TextEditingController thresholdController;

  AttributeSettingUIModel({
    required this.name,
    this.isEnabled = false,
    this.threshold = 0.7, // Default threshold
  }) : thresholdController = TextEditingController(text: threshold.toString());

  void dispose() {
    thresholdController.dispose();
  }
}

class FiltrosAdminContent extends StatefulWidget {
  const FiltrosAdminContent({super.key});

  @override
  FiltrosAdminContentState createState() => FiltrosAdminContentState();
}

class FiltrosAdminContentState extends State<FiltrosAdminContent> {
  bool _isPerspectiveServiceEnabledOverall =
      true; // For the main service switch
  bool _doNotStore = false;
  bool _spanAnnotations = false;

  // Using a Map to easily access settings by attribute name
  final Map<String, AttributeSettingUIModel> _attributeSettingsMap = {};

  // Supported attributes - should match backend
  final List<String> _supportedAttributes = [
    "TOXICITY",
    "SEVERE_TOXICITY",
    "IDENTITY_ATTACK",
    "INSULT",
    "PROFANITY",
    "THREAT",
    "SEXUALLY_EXPLICIT",
    "FLIRTATION",
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize UI models for each supported attribute
    for (var attrName in _supportedAttributes) {
      _attributeSettingsMap[attrName] = AttributeSettingUIModel(name: attrName);
    }
    _loadSettings(); // Load settings from backend
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    // Removed problematic ScaffoldMessenger call:
    // ScaffoldMessenger.of(context)
    //     .showSnackBar(const SnackBar(content: Text('Cargando configuración...')));

    try {
      final String url = ApiConfig().buildUrl(
        '/api/admin/perspective/settings',
      );
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final settings = jsonDecode(response.body);
        setState(() {
          _isPerspectiveServiceEnabledOverall = settings['isEnabled'] ?? true;
          _doNotStore = settings['doNotStore'] ?? false;
          _spanAnnotations = settings['spanAnnotations'] ?? false;

          final attributesFromServer =
              settings['attributeSettings'] as Map<String, dynamic>? ?? {};

          for (var attrName in _supportedAttributes) {
            final attrData =
                attributesFromServer[attrName] as Map<String, dynamic>?;
            if (attrData != null) {
              _attributeSettingsMap[attrName]!.isEnabled =
                  attrData['enabled'] ?? false;
              _attributeSettingsMap[attrName]!.threshold =
                  (attrData['threshold'] as num?)?.toDouble() ?? 0.7;
              _attributeSettingsMap[attrName]!.thresholdController.text =
                  _attributeSettingsMap[attrName]!.threshold.toString();
            } else {
              // If attribute is not in response, use default (already initialized)
              _attributeSettingsMap[attrName]!.isEnabled =
                  (attrName == "TOXICITY"); // Default TOXICITY to true
              _attributeSettingsMap[attrName]!.threshold = 0.7;
              _attributeSettingsMap[attrName]!.thresholdController.text = "0.7";
            }
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración cargada con éxito.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar configuración: ${'${response.statusCode}'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al cargar configuración: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveSettings() async {
    if (!mounted) return;

    // Validate all thresholds
    for (var attrName in _supportedAttributes) {
      final model = _attributeSettingsMap[attrName]!;
      final newThreshold = double.tryParse(model.thresholdController.text);
      if (newThreshold == null || newThreshold < 0.0 || newThreshold > 1.0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El umbral para "$attrName" debe ser un número entre 0.0 y 1.0.',
            ),
          ),
        );
        return;
      }
      model.threshold = newThreshold; // Update model's threshold before sending
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Guardando configuración...')));

    Map<String, dynamic> attributesToSave = {};
    _attributeSettingsMap.forEach((key, value) {
      attributesToSave[key] = {
        'enabled': value.isEnabled,
        'threshold': value.threshold,
      };
    });

    final payload = jsonEncode({
      'isEnabled': _isPerspectiveServiceEnabledOverall,
      'doNotStore': _doNotStore,
      'spanAnnotations': _spanAnnotations,
      'attributeSettings': attributesToSave,
    });

    try {
      final String url = ApiConfig().buildUrl(
        '/api/admin/perspective/settings',
      );
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: payload,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada con éxito.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar configuración: ${'${response.statusCode}'}. Detalles: ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión al guardar configuración: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (var model in _attributeSettingsMap.values) {
      model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      tr('content_filter_title'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // General Perspective Service Switch
                    SwitchListTile(
                      title: Text(tr('content_filter_enable_perspective')),
                      value: _isPerspectiveServiceEnabledOverall,
                      onChanged: (bool value) {
                        setState(() {
                          _isPerspectiveServiceEnabledOverall = value;
                        });
                      },
                      secondary: Icon(
                        _isPerspectiveServiceEnabledOverall
                            ? Icons.security
                            : Icons.security_outlined,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Text(
                      _isPerspectiveServiceEnabledOverall
                          ? tr('content_filter_service_active')
                          : tr('content_filter_service_inactive'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),

                    Text(
                      tr('content_filter_general_config'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: Text(tr('content_filter_do_not_store')),
                      value: _doNotStore,
                      onChanged: (bool value) {
                        setState(() {
                          _doNotStore = value;
                        });
                      },
                      secondary: const Icon(Icons.history_toggle_off),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Text(
                      _doNotStore
                          ? tr('content_filter_do_not_store_active')
                          : tr('content_filter_do_not_store_inactive'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: Text(tr('content_filter_span_annotations')),
                      value: _spanAnnotations,
                      onChanged: (bool value) {
                        setState(() {
                          _spanAnnotations = value;
                        });
                      },
                      secondary: const Icon(Icons.analytics_outlined),
                      contentPadding: EdgeInsets.zero,
                    ),
                    Text(
                      _spanAnnotations
                          ? tr('content_filter_span_annotations_active')
                          : tr('content_filter_span_annotations_inactive'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),

                    Text(
                      tr('content_filter_detailed_config'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('content_filter_threshold_description'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),

                    ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // To disable scrolling within the ListView
                      itemCount: _supportedAttributes.length,
                      itemBuilder: (context, index) {
                        final attrName = _supportedAttributes[index];
                        final model = _attributeSettingsMap[attrName]!;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  attrName
                                      .capitalizeFirstofEach, // Corrected: Removed parentheses
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  title: Text(
                                    tr('content_filter_enable_attribute'),
                                  ),
                                  value: model.isEnabled,
                                  onChanged: (bool value) {
                                    setState(() {
                                      model.isEnabled = value;
                                    });
                                  },
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                TextFormField(
                                  controller: model.thresholdController,
                                  decoration: InputDecoration(
                                    labelText: tr(
                                      'content_filter_threshold_label',
                                    ),
                                    hintText: tr(
                                      'content_filter_threshold_hint',
                                      args: [model.threshold.toString()],
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d{0,2}'),
                                    ),
                                  ],
                                  onSaved: (value) {
                                    // Also update on save or when focus changes
                                    final newThreshold = double.tryParse(
                                      value ?? "",
                                    );
                                    if (newThreshold != null &&
                                        newThreshold >= 0.0 &&
                                        newThreshold <= 1.0) {
                                      setState(() {
                                        model.threshold = newThreshold;
                                      });
                                    }
                                  },
                                  onChanged: (value) {
                                    // Live update for validation, actual save on _saveSettings
                                    final newThreshold = double.tryParse(value);
                                    if (newThreshold != null &&
                                        newThreshold >= 0.0 &&
                                        newThreshold <= 1.0) {
                                      // model.threshold = newThreshold; // Can update live if desired, but _saveSettings is the source of truth for saving
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 30),

                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: Text(tr('content_filter_save_button')),
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    Text(
                      tr('content_filter_important_note'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('content_filter_important_note_content'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
    );
  }
}

// Helper extension for capitalizing strings
extension StringExtension on String {
  String get capitalizeFirstofEach => replaceAll("_", " ")
      .toLowerCase()
      .split(" ")
      .map(
        (str) =>
            str.isNotEmpty ? '${str[0].toUpperCase()}${str.substring(1)}' : '',
      )
      .join(" ");
}
