import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/event.dart'; // Assuming event.dart is in the models directory
import 'add_suggestions_dialog.dart'; // Assuming this is another file you have

const Color primaryColor = Color(0xFF1A6B3C);
const Color accentColor = Color(0xFF4CAF50);
const Color backgroundColor = Colors.white;
const Color cardColor = Colors.white;
const Color subtleColor = Color(0xFFF5F5F5);

const Curve _animationCurve = Curves.easeInOut;

class EventDialog extends StatefulWidget {
  final DateTime date;
  final Map<DateTime, String> selectedAddresses;
  final Function() onSave;
  final Event? event;

  const EventDialog({
    super.key,
    required this.date,
    required this.onSave,
    required this.selectedAddresses,
    this.event,
  });

  @override
  _EventDialogState createState() => _EventDialogState();
}

class _EventDialogState extends State<EventDialog>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  late TextEditingController _autocompleteController;
  final TextEditingController _descriptionController = TextEditingController();
  late TextEditingController _reminderYearsController;
  late TextEditingController _reminderMonthsController;
  late TextEditingController _reminderDaysController;
  late TextEditingController _recurrenceCountController;
  String _selectedAddress = '';
  String _selectedType = 'other';
  List<Map<String, dynamic>> _eventSuggestions = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _reminderYears = 0;
  int _reminderMonths = 0;
  int _reminderDays = 0;
  bool _isRecurring = false;
  int? _recurrenceInterval;
  int _recurrenceDays = 0;
  int _recurrenceMinutes = 0;
  int? _recurrenceYears; // For multi-year recurrence
  int? _recurrenceDayOfMonth; // Fixed day for monthly/yearly
  bool _isCustomReminder = false;
  bool _hasReminder = false;
  String _recurrenceLimitType = 'count';
  int _recurrenceCount = 1;
  DateTime? _recurrenceEndDate;
  bool _isDisposed = false;
  int _selectedSuggestionIndex = -1;
  final FocusNode _autocompleteFocusNode = FocusNode();
  bool _isLoadingSuggestions = false;

  final _eventTypes = [
    {'value': 'meeting', 'icon': Icons.people, 'label': 'Meeting'},
    {'value': 'personal', 'icon': Icons.person, 'label': 'Personal'},
    {'value': 'work', 'icon': Icons.work, 'label': 'Work'},
    {'value': 'social', 'icon': Icons.people_outline, 'label': 'Social'},
    {'value': 'other', 'icon': Icons.more_horiz, 'label': 'Other'},
  ];

  final List<Map<String, dynamic>> _reminderOptions = [
    {'value': 0, 'label': 'No preset'},
    {'value': 1, 'label': '1 month before'},
    {'value': 4, 'label': '4 months before'},
    {'value': 12, 'label': '1 year before'},
    {'value': 10, 'label': 'Custom'},
  ];

  final List<Map<String, dynamic>> _recurrenceOptions = [
    {'value': 0, 'label': 'Custom'},
    {'value': 1, 'label': 'Daily'},
    {'value': 7, 'label': 'Weekly'},
    {'value': 14, 'label': 'Every 2 Weeks'},
    {'value': 30, 'label': 'Monthly (Same Day)'},
    {'value': 365, 'label': 'Yearly'},
  ];

  @override
  void initState() {
    super.initState();
    _autocompleteController = TextEditingController();
    _reminderYearsController = TextEditingController();
    _reminderMonthsController = TextEditingController();
    _reminderDaysController = TextEditingController();
    _recurrenceCountController = TextEditingController();
    _recurrenceYears = 1; // Default to 1 year
    _recurrenceDayOfMonth = widget.date.day; // Default to selected date's day
    _initializeData();
    _setupListeners();
  }

  Future<void> _initializeData() async {
    print('Initializing data for event: ${widget.event?.title}');
    if (widget.event != null) {
      _titleController.text = widget.event!.title ?? '';
      _autocompleteController.text = widget.event!.title ?? '';
      _descriptionController.text = widget.event!.description ?? '';
      _selectedAddress =
          widget.event!.address ?? widget.selectedAddresses[widget.date] ?? '';
      _selectedType = widget.event!.type ?? 'other';
      _reminderYears = widget.event!.reminderPeriodMonths ~/ 12;
      _reminderMonths = widget.event!.reminderPeriodMonths % 12;
      _reminderDays = widget.event!.reminderDays ?? 0;
      _isRecurring = widget.event!.isRecurring ?? false;
      _recurrenceInterval = widget.event!.recurrenceInterval;
      _recurrenceDays = widget.event!.recurrenceDays ?? 0;
      _recurrenceMinutes = widget.event!.recurrenceMinutes ?? 0;
      _recurrenceYears = widget.event!.recurrenceDays ~/ 365 > 0
          ? widget.event!.recurrenceDays ~/ 365
          : 1;
      _recurrenceDayOfMonth =
          widget.event!.recurrenceDayOfMonth ?? widget.date.day;
      _recurrenceCount = widget.event!.recurrenceCount ?? 1;
      _recurrenceEndDate = widget.event!.recurrenceEndDate;
      _recurrenceLimitType = widget.event!.recurrenceCount != null
          ? 'count'
          : widget.event!.recurrenceEndDate != null
              ? 'date'
              : 'count';
      _hasReminder =
          _reminderYears > 0 || _reminderMonths > 0 || _reminderDays > 0;
      _isCustomReminder =
          _reminderDays > 0 || _reminderYears > 0 || _reminderMonths < 0;
      if (_reminderMonths < 0) _reminderMonths = 0;
      if (_reminderYears < 0) _reminderYears = 0;
    } else {
      _selectedAddress = widget.selectedAddresses[widget.date] ?? '';
      _reminderYears = 0;
      _reminderMonths = 0;
      _reminderDays = 0;
      _recurrenceCountController.text = '1';
    }
    await _loadSuggestions();
    if (mounted) setState(() {});
  }

  void _updateTextControllers() {
    if (!_isDisposed) {
      _reminderYearsController.text =
          _reminderYears > 0 ? _reminderYears.toString() : '';
      _reminderMonthsController.text =
          _reminderMonths > 0 ? _reminderMonths.toString() : '';
      _reminderDaysController.text =
          _reminderDays > 0 ? _reminderDays.toString() : '';
      _recurrenceCountController.text = _recurrenceCount.toString();
    }
  }

  void _setupListeners() {
    _titleController.addListener(_titleListener);
    _recurrenceCountController.addListener(_recurrenceCountListener);
  }

  void _titleListener() {
    if (!_isDisposed) {
      _autocompleteController.text = _titleController.text;
    }
  }

  void _recurrenceCountListener() {
    if (!_isDisposed) {
      setState(() {
        _recurrenceCount = int.tryParse(_recurrenceCountController.text) ?? 1;
        if (_recurrenceCount < 1) _recurrenceCount = 1;
      });
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _titleController.removeListener(_titleListener);
    _recurrenceCountController.removeListener(_recurrenceCountListener);
    _titleController.dispose();
    _autocompleteController.dispose();
    _descriptionController.dispose();
    _reminderYearsController.dispose();
    _reminderMonthsController.dispose();
    _reminderDaysController.dispose();
    _recurrenceCountController.dispose();
    _autocompleteFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final querySnapshot = await _firestore.collection('suggestions').get();
      if (!_isDisposed && mounted) {
        setState(() {
          _eventSuggestions = querySnapshot.docs
              .where((doc) {
                final data = doc.data();
                final title = data['title'];
                return title != null && title is String && title.isNotEmpty;
              })
              .map((doc) => {
                    'id': doc.id,
                    'title': doc.data()['title'] as String? ?? '',
                  })
              .toList();
          print(
              'Loaded ${_eventSuggestions.length} suggestions: ${_eventSuggestions.map((s) => s['title']).toList()}');
        });
      }
    } catch (e) {
      print('Error loading suggestions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load suggestions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedAddress.isEmpty
                        ? 'No Property Selected'
                        : _selectedAddress,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _selectAddress,
              icon: Icon(_selectedAddress.isEmpty ? Icons.add : Icons.edit,
                  size: 18),
              label: Text(_selectedAddress.isEmpty
                  ? 'Add Property'
                  : 'Change Property'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor.withOpacity(0.2),
                foregroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _eventTypes.map((type) {
        final isSelected = type['value'] == _selectedType;
        return FilterChip(
          selected: isSelected,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(type['icon'] as IconData,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[700]),
              const SizedBox(width: 4),
              Text(
                type['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
          backgroundColor: subtleColor,
          selectedColor: accentColor,
          onSelected: (bool selected) {
            if (!_isDisposed) {
              setState(() => _selectedType = type['value'] as String);
            }
          },
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
                color: isSelected ? Colors.transparent : Colors.grey[300]!),
          ),
          elevation: isSelected ? 2 : 0,
          pressElevation: 4,
        );
      }).toList(),
    );
  }

  Widget _buildReminderSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _buildSectionTitle('Reminder')),
                Switch(
                  value: _hasReminder,
                  onChanged: (value) {
                    if (!_isDisposed) {
                      setState(() {
                        _hasReminder = value;
                        if (!value) {
                          _reminderYears = 0;
                          _reminderMonths = 0;
                          _reminderDays = 0;
                          _isCustomReminder = false;
                          _updateTextControllers();
                        }
                      });
                    }
                  },
                  activeColor: accentColor,
                  activeTrackColor: accentColor.withOpacity(0.5),
                ),
              ],
            ),
            if (_hasReminder) ...[
              DropdownButtonFormField<int>(
                value: _isCustomReminder
                    ? 10
                    : (_reminderYears > 0 ? 12 : _reminderMonths),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: subtleColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: primaryColor.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: accentColor, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _reminderOptions.map((option) {
                  return DropdownMenuItem<int>(
                    value: option['value'] as int,
                    child: Text(option['label'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  if (!_isDisposed && value != null) {
                    setState(() {
                      if (value == 10) {
                        _isCustomReminder = true;
                        _reminderYears = 0;
                        _reminderMonths = 0;
                        _reminderDays = 0;
                      } else {
                        _isCustomReminder = false;
                        _reminderYears = value == 12 ? 1 : 0;
                        _reminderMonths = value == 12 ? 0 : value;
                        _reminderDays = 0;
                      }
                      _updateTextControllers();
                    });
                  }
                },
                dropdownColor: cardColor,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
              if (_isCustomReminder) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reminderYearsController,
                        decoration: InputDecoration(
                          labelText: 'Years',
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (!_isDisposed) {
                            setState(() {
                              _reminderYears = int.tryParse(value) ?? 0;
                              if (_reminderYears < 0) _reminderYears = 0;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _reminderMonthsController,
                        decoration: InputDecoration(
                          labelText: 'Months',
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (!_isDisposed) {
                            setState(() {
                              _reminderMonths = int.tryParse(value) ?? 0;
                              if (_reminderMonths < 0) _reminderMonths = 0;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _reminderDaysController,
                        decoration: InputDecoration(
                          labelText: 'Days',
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: accentColor, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          if (!_isDisposed) {
                            setState(() {
                              _reminderDays = int.tryParse(value) ?? 0;
                              if (_reminderDays < 0) _reminderDays = 0;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceSettings() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Recurrence'),
            SwitchListTile(
              title:
                  const Text('Recurring Task', style: TextStyle(fontSize: 14)),
              value: _isRecurring,
              onChanged: (value) {
                if (!_isDisposed) {
                  setState(() {
                    _isRecurring = value;
                    if (!value) {
                      _recurrenceInterval = null;
                      _recurrenceDays = 0;
                      _recurrenceMinutes = 0;
                      _recurrenceYears = 1;
                      _recurrenceDayOfMonth = widget.date.day;
                      _recurrenceLimitType = 'count';
                      _recurrenceCount = 1;
                      _recurrenceEndDate = null;
                    }
                  });
                }
              },
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: accentColor,
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _recurrenceInterval ?? 0,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: subtleColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: primaryColor.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: accentColor, width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _recurrenceOptions.map((option) {
                  return DropdownMenuItem<int>(
                    value: option['value'] as int,
                    child: Text(option['label'] as String),
                  );
                }).toList(),
                onChanged: (value) {
                  if (!_isDisposed && value != null) {
                    setState(() {
                      _recurrenceInterval = value;
                      if (value == 30 || value == 365) {
                        _recurrenceDays = 0;
                        _recurrenceMinutes = 0;
                      } else if (value != 0) {
                        _recurrenceDays = value;
                        _recurrenceMinutes = 0;
                      }
                    });
                  }
                },
                dropdownColor: cardColor,
                style: const TextStyle(color: Colors.black87, fontSize: 16),
              ),
              if (_recurrenceInterval == 0 ||
                  _recurrenceInterval == 30 ||
                  _recurrenceInterval == 365) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_recurrenceInterval == 365)
                      Expanded(
                        child: TextFormField(
                          initialValue: _recurrenceYears.toString(),
                          decoration: InputDecoration(
                            labelText: 'Every X Years',
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: accentColor, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (!_isDisposed) {
                              setState(() {
                                _recurrenceYears = int.tryParse(value) ?? 1;
                                if (_recurrenceYears! < 1) _recurrenceYears = 1;
                              });
                            }
                          },
                        ),
                      ),
                    if (_recurrenceInterval == 365 || _recurrenceInterval == 30)
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _recurrenceDayOfMonth,
                          decoration: InputDecoration(
                            labelText: _recurrenceInterval == 365
                                ? 'Day of Year'
                                : 'Day of Month',
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          items: List.generate(31, (index) => index + 1)
                              .map((day) {
                            return DropdownMenuItem<int>(
                              value: day,
                              child: Text(day.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (!_isDisposed && value != null) {
                              setState(() {
                                _recurrenceDayOfMonth = value;
                              });
                            }
                          },
                        ),
                      ),
                    if (_recurrenceInterval == 0) ...[
                      Expanded(
                        child: TextFormField(
                          initialValue: _recurrenceDays.toString(),
                          decoration: InputDecoration(
                            labelText: 'Days',
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: accentColor, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (!_isDisposed) {
                              setState(() {
                                _recurrenceDays = int.tryParse(value) ?? 0;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _recurrenceMinutes.toString(),
                          decoration: InputDecoration(
                            labelText: 'Minutes',
                            filled: true,
                            fillColor: cardColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                  color: accentColor, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            if (!_isDisposed) {
                              setState(() {
                                _recurrenceMinutes = int.tryParse(value) ?? 0;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _buildRecurrenceLimitSettings(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceLimitSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repeat Until:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _recurrenceLimitType,
          decoration: InputDecoration(
            filled: true,
            fillColor: subtleColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: accentColor, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          items: const [
            DropdownMenuItem(value: 'count', child: Text('Number of Times')),
            DropdownMenuItem(value: 'date', child: Text('End Date')),
          ],
          onChanged: (value) {
            if (!_isDisposed && value != null) {
              setState(() {
                _recurrenceLimitType = value;
                if (value == 'count') {
                  _recurrenceEndDate = null;
                } else if (value == 'date') {
                  _recurrenceCount = 1;
                }
                _updateTextControllers();
              });
            }
          },
          dropdownColor: cardColor,
          style: const TextStyle(color: Colors.black87, fontSize: 16),
        ),
        if (_recurrenceLimitType == 'count') ...[
          const SizedBox(height: 12),
          TextField(
            controller: _recurrenceCountController,
            decoration: InputDecoration(
              labelText: 'Number of Occurrences',
              filled: true,
              fillColor: cardColor,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: accentColor, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
        if (_recurrenceLimitType == 'date') ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickEndDate,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: subtleColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _recurrenceEndDate != null
                        ? '${_recurrenceEndDate!.year}-${_recurrenceEndDate!.month}-${_recurrenceEndDate!.day}'
                        : 'Select End Date',
                    style: TextStyle(
                        color: _recurrenceEndDate == null
                            ? Colors.grey[600]
                            : Colors.black87),
                  ),
                  Icon(Icons.calendar_today, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          child: Scaffold(
            backgroundColor: cardColor,
            body: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      widget.event == null
                          ? 'Add New Event'
                          : 'Edit Event: ${widget.event!.title}',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor),
                    ),
                  ),
                  _buildAddressSection(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('Event Type'),
                  _buildTypeSelector(),
                  const SizedBox(height: 16),
                  _isLoadingSuggestions
                      ? const Center(child: CircularProgressIndicator())
                      : Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            final filtered = _eventSuggestions
                                .map((suggestion) =>
                                    suggestion['title'] as String)
                                .where((suggestion) => suggestion
                                    .toLowerCase()
                                    .contains(
                                        textEditingValue.text.toLowerCase()))
                                .toList();
                            print(
                                'Filtered suggestions for "${textEditingValue.text}": $filtered');
                            return filtered;
                          },
                          onSelected: (selection) {
                            if (!_isDisposed) {
                              setState(() {
                                _titleController.text = selection;
                                _autocompleteController.text = selection;
                                _selectedSuggestionIndex = -1;
                              });
                            }
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            controller.text = _titleController.text;
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Event Title',
                                prefixIcon: const Icon(Icons.event),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: subtleColor,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: accentColor, width: 2),
                                ),
                              ),
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              onChanged: (value) {
                                _titleController.text = value;
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final optionList = options.toList();
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                    maxHeight: 200,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: optionList.length,
                                    itemBuilder: (context, index) {
                                      final option = optionList[index];
                                      return ListTile(
                                        title: Text(option),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Comments',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: subtleColor,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: accentColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addNewSuggestionDialog,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('Add Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          elevation: 2,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showOptionsDialog,
                        icon: const Icon(Icons.more_horiz),
                        label: const Text('Options'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildReminderSettings(),
                  const SizedBox(height: 16),
                  _buildRecurrenceSettings(),
                ],
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _saveEvent(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      elevation: 2,
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardColor,
        elevation: 4,
        title: const Text(
          'Options',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.lightbulb_outline, color: primaryColor),
              title: const Text('Add Event', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _addNewSuggestionDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: primaryColor),
              title:
                  const Text('Manage Events', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _showManageSuggestionsDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _addNewSuggestionDialog() async {
    final newSuggestion = await showDialog<String>(
      context: context,
      builder: (context) => const AddSuggestionDialog(),
    );
    if (newSuggestion != null && newSuggestion.isNotEmpty && !_isDisposed) {
      await _addNewSuggestion(newSuggestion);
    }
  }

  Future<void> _addNewSuggestion(String suggestion) async {
    try {
      await _firestore.collection('suggestions').add({'title': suggestion});
      await _loadSuggestions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suggestion added successfully'),
          backgroundColor: accentColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error adding suggestion: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error adding suggestion: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _showManageSuggestionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardColor,
        elevation: 4,
        title: const Text(
          'Manage Suggestions',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          height: 300,
          child: _eventSuggestions.isEmpty
              ? const Center(child: Text('No suggestions available. Add some!'))
              : ListView.builder(
                  itemCount: _eventSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _eventSuggestions[index];
                    return ListTile(
                      title: Text(suggestion['title'] as String),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _deleteSuggestion(suggestion['id'] as String),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSuggestion(String suggestionId) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardColor,
        elevation: 4,
        title: const Text(
          'Delete Suggestion',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: const Text('Are you sure you want to delete this suggestion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 14)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );

    if (confirmDelete == true && !_isDisposed) {
      try {
        await _firestore.collection('suggestions').doc(suggestionId).delete();
        await _loadSuggestions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suggestion deleted successfully'),
            backgroundColor: accentColor,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        print('Error deleting suggestion: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting suggestion: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _pickEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: widget.date.add(const Duration(days: 1)),
      firstDate: widget.date,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && !_isDisposed) {
      setState(() {
        _recurrenceEndDate = pickedDate;
      });
    }
  }

  Future<void> _selectAddress() async {
    final selectedAddress = await showDialog<String>(
      context: context,
      builder: (context) => _SavedAddressesDialog(),
    );
    if (selectedAddress != null && selectedAddress.isNotEmpty && !_isDisposed) {
      setState(() {
        _selectedAddress = selectedAddress;
        widget.selectedAddresses[widget.date] = selectedAddress;
      });
    }
  }

  Future<void> _saveEvent(BuildContext context) async {
    final currentTitle = _autocompleteController.text;

    if (!_isDisposed) {
      if (currentTitle.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Event title is required'),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (_hasReminder &&
          _reminderYears == 0 &&
          _reminderMonths == 0 &&
          _reminderDays == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Set a reminder period'),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (_isRecurring &&
          _recurrenceDays == 0 &&
          _recurrenceMinutes == 0 &&
          (_recurrenceInterval != 30 && _recurrenceInterval != 365)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Set a recurrence interval'),
              backgroundColor: Colors.red),
        );
        return;
      }
      if (_isRecurring &&
          _recurrenceLimitType == 'date' &&
          _recurrenceEndDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select an end date for recurrence'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final eventId = FirebaseFirestore.instance.collection('events').doc().id;

      final event = Event(
        id: eventId,
        title: currentTitle,
        date: widget.date,
        startTime: widget.date,
        description: _descriptionController.text,
        address: _selectedAddress.isNotEmpty
            ? _selectedAddress
            : 'No Address Selected',
        type: _selectedType,
        isRecurring: _isRecurring,
        recurrenceInterval: _isRecurring ? _recurrenceInterval : null,
        reminderPeriodMonths:
            _hasReminder ? (_reminderYears * 12 + _reminderMonths) : 0,
        reminderDays: _hasReminder ? _reminderDays : 0,
        recurrenceDays: _recurrenceInterval == 365
            ? (_recurrenceYears ?? 1) * 365
            : _recurrenceDays,
        recurrenceMinutes: _recurrenceMinutes,
        recurrenceDayOfMonth: _isRecurring ? _recurrenceDayOfMonth : null,
        excludedDates: widget.event?.excludedDates ?? [],
        recurrenceCount:
            _recurrenceLimitType == 'count' ? _recurrenceCount : null,
        recurrenceEndDate:
            _recurrenceLimitType == 'date' ? _recurrenceEndDate : null,
        notified: widget.event?.notified,
      );

      try {
        print(
            'Saving event: ID=${event.id}, title=${event.title}, date=${event.date}, recurrenceCount=${event.recurrenceCount}');
        await Event.addEvent(event);

        if (widget.event != null) {
          print('Deleting old event: ID=${widget.event!.id}');
          await Event.removeEvent(widget.event!);
        }

        widget.onSave();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        print('Error saving event: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving event: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _SavedAddressesDialog extends StatefulWidget {
  @override
  __SavedAddressesDialogState createState() => __SavedAddressesDialogState();
}

class __SavedAddressesDialogState extends State<_SavedAddressesDialog> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _savedAddresses = []; // {id, address}
  List<Map<String, String>> _filteredAddresses = [];
  int _selectedIndex = -1;
  final FocusNode _focusNode = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isManagementMode = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _controller.addListener(() {
      _filterAddresses(_controller.text);
    });
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final querySnapshot =
          await _firestore.collection('saved_addresses').get();
      if (mounted) {
        setState(() {
          _savedAddresses = querySnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'address': doc['address'] as String,
                  })
              .toList();
          _filteredAddresses = List.from(_savedAddresses);
          print(
              'Loaded addresses: ${_savedAddresses.map((a) => a['address'])}');
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading addresses: $e')),
        );
      }
    }
  }

  void _filterAddresses(String query) {
    if (mounted) {
      setState(() {
        _filteredAddresses = _savedAddresses
            .where((address) =>
                address['address']!.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _selectedIndex = -1;
      });
    }
  }

  Future<void> _addAddress(String address) async {
    if (address.isEmpty) return;
    try {
      final docRef = await _firestore
          .collection('saved_addresses')
          .add({'address': address});
      await _loadSavedAddresses();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address added successfully'),
          backgroundColor: accentColor,
        ),
      );
      if (!_isManagementMode) {
        Navigator.pop(context, address);
      }
    } catch (e) {
      print('Error adding address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding address: $e')),
      );
    }
  }

  Future<void> _editAddress(String id, String oldAddress) async {
    final newAddress = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address'),
        content: TextField(
          controller: TextEditingController(text: oldAddress),
          decoration: const InputDecoration(labelText: 'New Address'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, oldAddress),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newAddress != null &&
        newAddress.isNotEmpty &&
        newAddress != oldAddress) {
      try {
        await _firestore
            .collection('saved_addresses')
            .doc(id)
            .update({'address': newAddress});
        await _loadSavedAddresses();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address updated successfully'),
            backgroundColor: accentColor,
          ),
        );
      } catch (e) {
        print('Error editing address: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error editing address: $e')),
        );
      }
    }
  }

  Future<void> _deleteAddress(String id) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmDelete == true) {
      try {
        await _firestore.collection('saved_addresses').doc(id).delete();
        await _loadSavedAddresses();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted successfully'),
            backgroundColor: accentColor,
          ),
        );
      } catch (e) {
        print('Error deleting address: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting address: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardColor,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isManagementMode ? 'Manage Addresses' : 'Select Address',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                  ),
                  IconButton(
                    icon: Icon(
                        _isManagementMode ? Icons.select_all : Icons.edit,
                        color: primaryColor),
                    onPressed: () {
                      setState(() {
                        _isManagementMode = !_isManagementMode;
                        _controller.clear();
                        _filterAddresses('');
                      });
                    },
                    tooltip: _isManagementMode
                        ? 'Switch to Select Mode'
                        : 'Manage Addresses',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Type Address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: subtleColor,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: accentColor, width: 2),
                  ),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => _addAddress(value),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _filteredAddresses.isEmpty
                    ? const Center(child: Text('No addresses available.'))
                    : ListView.builder(
                        itemCount: _filteredAddresses.length,
                        itemBuilder: (context, index) {
                          final address = _filteredAddresses[index];
                          return ListTile(
                            title: Text(address['address']!),
                            trailing: _isManagementMode
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: primaryColor),
                                        onPressed: () => _editAddress(
                                            address['id']!,
                                            address['address']!),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deleteAddress(address['id']!),
                                      ),
                                    ],
                                  )
                                : null,
                            onTap: _isManagementMode
                                ? null
                                : () =>
                                    Navigator.pop(context, address['address']),
                            tileColor: _selectedIndex == index
                                ? accentColor.withOpacity(0.2)
                                : null,
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isManagementMode
                        ? null
                        : () => _addAddress(_controller.text),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
