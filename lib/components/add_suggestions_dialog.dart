import 'package:flutter/material.dart';

class AddSuggestionDialog extends StatefulWidget {
  const AddSuggestionDialog({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AddSuggestionDialogState createState() => _AddSuggestionDialogState();
}

class _AddSuggestionDialogState extends State<AddSuggestionDialog> {
  final TextEditingController _suggestionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[300],
      title: const Text('Add New Suggestion'),
      content: TextField(
        controller: _suggestionController,
        decoration: const InputDecoration(
          hintText: 'Enter a new suggestion',
          focusedBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.black)),
          enabledBorder:
              OutlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.black),
          ),
        ),
        TextButton(
          onPressed: () {
            final newSuggestion = _suggestionController.text.trim();
            if (newSuggestion.isNotEmpty) {
              Navigator.pop(
                  context, newSuggestion); // Return the new suggestion
            }
          },
          child: const Text(
            'Add',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }
}
