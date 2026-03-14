import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:naukariwala/services/places_autocomplete_service.dart';

/// A text field that shows Google Places Autocomplete suggestions for addresses
/// in India only. Use for onboarding location/address.
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final bool enabled;
  final InputDecoration? decoration;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    this.labelText = 'Address',
    this.helperText,
    this.textInputAction,
    this.validator,
    this.enabled = true,
    this.decoration,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (formState) {
        return TypeAheadField<String>(
          controller: widget.controller,
          focusNode: _focusNode,
          debounceDuration: const Duration(milliseconds: 350),
          hideOnEmpty: true,
          hideOnSelect: true,
          hideOnLoading: false,
          suggestionsCallback: (pattern) =>
              PlacesAutocompleteService.getSuggestions(pattern),
          itemBuilder: (context, suggestion) => ListTile(
            dense: true,
            title: Text(
              suggestion,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onSelected: (suggestion) {
            widget.controller.text = suggestion;
            formState.didChange(suggestion);
          },
          loadingBuilder: (context) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SizedBox(
              height: 24,
              width: 24,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          emptyBuilder: (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              'No places found. Try a different search (India only).',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          builder: (context, controller, focusNode) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              enabled: widget.enabled,
              textInputAction:
                  widget.textInputAction ?? TextInputAction.done,
              decoration: (widget.decoration ?? const InputDecoration()).copyWith(
                labelText: widget.labelText,
                helperText: widget.helperText,
                hintText: 'Start typing your city or address...',
                errorText: formState.errorText,
              ),
              onChanged: (value) => formState.didChange(value),
            );
          },
        );
      },
    );
  }
}
