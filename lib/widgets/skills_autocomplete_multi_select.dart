import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

class SkillsAutocompleteMultiSelect extends StatefulWidget {
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;
  final String labelText;
  final String hintText;
  final int maxSuggestions;
  final FormFieldValidator<List<String>>? validator;

  const SkillsAutocompleteMultiSelect({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.labelText = 'Select Skills',
    this.hintText = 'Type a skill',
    this.maxSuggestions = 20,
    this.validator,
  });

  static Future<List<String>>? _cachedSkillsFuture;

  static Future<List<String>> _loadSkills() {
    _cachedSkillsFuture ??= () async {
      final raw = await rootBundle.loadString('assets/data/skills.json');
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];

      final skills = decoded
          .map((e) {
            if (e is String) return e;
            if (e is Map && e['skill'] is String) return e['skill'] as String;
            return null;
          })
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      skills.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return skills;
    }();
    return _cachedSkillsFuture!;
  }

  @override
  State<SkillsAutocompleteMultiSelect> createState() =>
      _SkillsAutocompleteMultiSelectState();
}

class _SkillsAutocompleteMultiSelectState
    extends State<SkillsAutocompleteMultiSelect> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<List<String>>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        // Keep FormField state in-sync with external value so validation/error
        // clears immediately when parent state changes.
        final fieldValue = field.value ?? const <String>[];
        if (!listEquals(fieldValue, widget.value)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            field.didChange(widget.value);
          });
        }

        void updateValue(List<String> next) {
          field.didChange(next);
          widget.onChanged(next);
          _controller.clear();
          _focusNode.requestFocus();
        }

        void addSkill(String skill) {
          final trimmed = skill.trim();
          if (trimmed.isEmpty) return;
          final current = field.value ?? const <String>[];
          if (current.contains(trimmed)) return;
          updateValue([...current, trimmed]);
        }

        void removeSkill(String skill) {
          final current = field.value ?? const <String>[];
          updateValue(current.where((s) => s != skill).toList());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<List<String>>(
              future: SkillsAutocompleteMultiSelect._loadSkills(),
              builder: (context, snap) {
                final allSkills = snap.data ?? const <String>[];
                return TypeAheadField<String>(
                  controller: _controller,
                  focusNode: _focusNode,
                  hideOnEmpty: true,
                  suggestionsCallback: (search) {
                    final q = search.trim().toLowerCase();
                    if (q.isEmpty) return const <String>[];
                    final selectedLower =
                        (field.value ?? const <String>[])
                            .map((e) => e.toLowerCase())
                            .toSet();
                    return allSkills
                        .where((s) =>
                            !selectedLower.contains(s.toLowerCase()) &&
                            s.toLowerCase().contains(q))
                        .take(widget.maxSuggestions)
                        .toList();
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      dense: true,
                      title: Text(suggestion),
                    );
                  },
                  onSelected: widget.enabled ? addSkill : null,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: widget.enabled,
                      decoration: InputDecoration(
                        labelText: widget.labelText,
                        hintText: widget.hintText,
                        prefixIcon: const Icon(Icons.search),
                        errorText: field.errorText,
                      ),
                    );
                  },
                );
              },
            ),
            if ((field.value ?? const <String>[]).isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (field.value ?? const <String>[]).map((s) {
                  return Chip(
                    label: Text(s, overflow: TextOverflow.ellipsis),
                    onDeleted: widget.enabled ? () => removeSkill(s) : null,
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

