part of '../import_screen.dart';

class _MapColumns extends StatelessWidget {
  const _MapColumns({
    required this.header,
    required this.mapping,
    required this.onChanged,
    required this.onContinue,
    required this.onCancel,
  });

  final List<String> header;
  final CsvMapping mapping;
  final ValueChanged<CsvMapping> onChanged;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  CsvMapping _with({
    int? title,
    int? status,
    int? date,
    int? rating,
    String? field,
  }) => CsvMapping(
    title: title ?? mapping.title,
    status: field == 'status' ? status : mapping.status,
    date: field == 'date' ? date : mapping.date,
    rating: field == 'rating' ? rating : mapping.rating,
    delimiter: mapping.delimiter,
  );

  @override
  Widget build(BuildContext context) {
    Widget picker(
      String label,
      int? value,
      ValueChanged<int?> set, {
      bool optional = true,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: CueSpace.md),
        child: DropdownButtonFormField<int?>(
          isExpanded: true,
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            if (optional)
              const DropdownMenuItem(
                value: null,
                child: Text('Not in this file'),
              ),
            for (var i = 0; i < header.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(header[i].isEmpty ? 'Column ${i + 1}' : header[i]),
              ),
          ],
          onChanged: set,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tell Cue which columns hold what. Values are read as plain text.',
          style: _muted,
        ),
        const SizedBox(height: CueSpace.lg),
        picker(
          'Title',
          mapping.title,
          (v) => onChanged(_with(title: v ?? 0)),
          optional: false,
        ),
        picker(
          'Status (optional)',
          mapping.status,
          (v) => onChanged(_with(status: v, field: 'status')),
        ),
        picker(
          'Date watched (optional)',
          mapping.date,
          (v) => onChanged(_with(date: v, field: 'date')),
        ),
        picker(
          'Your rating (optional)',
          mapping.rating,
          (v) => onChanged(_with(rating: v, field: 'rating')),
        ),
        Row(
          spacing: CueSpace.md,
          children: [
            CueSecondaryButton(label: 'Cancel', onPressed: onCancel),
            CuePrimaryButton(label: 'Continue', onPressed: onContinue),
          ],
        ),
      ],
    );
  }
}
