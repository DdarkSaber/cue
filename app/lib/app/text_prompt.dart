import 'package:flutter/material.dart';

/// Asks for one line of text. Returns the text, '' when [clearLabel] was
/// chosen, or null when dismissed. The dialog owns its controller, so it is
/// only disposed once the closing animation is over.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initial = '',
  String? hint,
  String? clearLabel,
  int maxLength = 200,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    confirmLabel: confirmLabel,
    initial: initial,
    hint: hint,
    clearLabel: clearLabel,
    maxLength: maxLength,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.confirmLabel,
    required this.initial,
    required this.hint,
    required this.clearLabel,
    required this.maxLength,
  });

  final String title;
  final String confirmLabel;
  final String initial;
  final String? hint;
  final String? clearLabel;
  final int maxLength;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: widget.maxLength,
      decoration: InputDecoration(hintText: widget.hint),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      if (widget.clearLabel != null && widget.initial.isNotEmpty)
        TextButton(
          onPressed: () => Navigator.of(context).pop(''),
          child: Text(widget.clearLabel!),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
