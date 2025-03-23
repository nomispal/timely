import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timely/models/event.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const Color primaryColor = Color(0xFF1A6B3C); // Dark green
const Color accentColor = Color(0xFF4CAF50); // Light green
const Color subtleColor = Color(0xFFF5F5F5); // Light grey

class PrintEventsScreen extends StatefulWidget {
  const PrintEventsScreen({super.key});

  @override
  State<PrintEventsScreen> createState() => _PrintEventsScreenState();
}

class _PrintEventsScreenState extends State<PrintEventsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  List<String> _selectedProperties = [];
  List<String> _availableProperties = [];
  String searchQuery = '';
  String _sortOption = 'Date'; // Default sort by date
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadAvailableProperties();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableProperties() async {
    final snapshot = await _firestore.collection('events').get();
    final properties = snapshot.docs
        .map((doc) => doc['address'] as String?)
        .where((address) => address != null && address != 'No Address Selected')
        .cast<String>()
        .toSet()
        .toList();
    setState(() {
      _availableProperties = properties;
    });
  }

  void _selectDateRange() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.white, subtleColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.calendar_today, color: primaryColor, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDateDropdown('Start Date', _selectedStartDate, (date) {
                setState(() {
                  _selectedStartDate = date;
                });
              }),
              const SizedBox(height: 12),
              _buildDateDropdown('End Date', _selectedEndDate, (date) {
                setState(() {
                  _selectedEndDate = date;
                });
              }),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStartDate = null;
                        _selectedEndDate = null;
                      });
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Reset',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (_selectedStartDate != null &&
                              _selectedEndDate != null) {
                            if (_selectedStartDate!
                                .isAfter(_selectedEndDate!)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('End date must be after start date'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please select both start and end dates'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 4,
                          shadowColor: accentColor.withOpacity(0.4),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateDropdown(
      String label, DateTime? selectedDate, Function(DateTime?) onChanged) {
    int? selectedYear;
    int? selectedMonth;
    int? selectedDay;

    if (selectedDate != null) {
      selectedYear = selectedDate.year;
      selectedMonth = selectedDate.month;
      selectedDay = selectedDate.day;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Flexible(
              flex: 2,
              child: _buildPrettyDropdown<int>(
                label: 'Year',
                items: List.generate(81, (index) => 2020 + index),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedYear = value;
                      if (selectedMonth != null && selectedDay != null) {
                        final newDate = _validateDate(
                            selectedYear!, selectedMonth!, selectedDay!);
                        onChanged(newDate);
                      } else {
                        onChanged(null);
                      }
                    });
                  }
                },
                value: selectedYear,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 3,
              child: _buildPrettyDropdown<int>(
                label: 'Month',
                items: List.generate(12, (index) => index + 1),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedMonth = value;
                      if (selectedYear != null && selectedDay != null) {
                        final newDate = _validateDate(
                            selectedYear!, selectedMonth!, selectedDay!);
                        onChanged(newDate);
                      } else {
                        onChanged(null);
                      }
                    });
                  }
                },
                value: selectedMonth,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: _buildPrettyDropdown<int>(
                label: 'Day',
                items: List.generate(31, (index) => index + 1),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedDay = value;
                      if (selectedYear != null && selectedMonth != null) {
                        final newDate = _validateDate(
                            selectedYear!, selectedMonth!, selectedDay!);
                        onChanged(newDate);
                      } else {
                        onChanged(null);
                      }
                    });
                  }
                },
                value: selectedDay,
              ),
            ),
          ],
        ),
      ],
    );
  }

  DateTime _validateDate(int year, int month, int day) {
    try {
      final date = DateTime(year, month, day);
      final lastDayOfMonth = DateTime(year, month + 1, 0).day;
      if (day > lastDayOfMonth) {
        return DateTime(year, month, lastDayOfMonth);
      }
      return date;
    } catch (e) {
      return DateTime(year, month, 1);
    }
  }

  Widget _buildPrettyDropdown<T>({
    required String label,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required T? value,
  }) {
    return DropdownButtonFormField<T>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: subtleColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      value: value,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(
            item is int
                ? (label == 'Month'
                    ? DateFormat('MMM').format(DateTime(0, item))
                    : item.toString())
                : item.toString(),
            style: const TextStyle(color: primaryColor, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 16, color: Colors.black87),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down, color: primaryColor),
    );
  }

  Future<void> _selectProperties() async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => MultiSelectDialog(
        items: _availableProperties,
        initialSelected: _selectedProperties,
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedProperties = selected;
      });
    }
  }

  Future<List<Event>> _getFilteredEvents() async {
    final snapshot = await _firestore.collection('events').get();
    final events =
        snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();

    // Apply filters
    var filteredEvents = events.where((event) {
      bool matchesDateRange = _selectedStartDate == null ||
          _selectedEndDate == null ||
          (event.date.isAfter(
                  _selectedStartDate!.subtract(const Duration(days: 1))) &&
              event.date
                  .isBefore(_selectedEndDate!.add(const Duration(days: 1))));
      bool matchesProperties = _selectedProperties.isEmpty ||
          _selectedProperties.contains(event.address);
      bool matchesSearch = searchQuery.isEmpty ||
          event.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (event.description?.toLowerCase() ?? '')
              .contains(searchQuery.toLowerCase());

      return matchesDateRange && matchesProperties && matchesSearch;
    }).toList();

    // Sort events based on _sortOption
    if (_sortOption == 'Date') {
      filteredEvents
          .sort((a, b) => a.date.compareTo(b.date)); // Nearest to furthest
    } else if (_sortOption == 'Type') {
      filteredEvents.sort((a, b) => a.type
          .toLowerCase()
          .compareTo(b.type.toLowerCase())); // Alphabetically by type (A-Z)
    }

    return filteredEvents;
  }

  Future<void> _printEvents() async {
    final events = await _getFilteredEvents();
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No events to print'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Events Report',
                  style: const pw.TextStyle(fontSize: 20)), // Removed bold
            ),
            if (_selectedStartDate != null && _selectedEndDate != null)
              pw.Text(
                  'Date Range: ${DateFormat('MMMM d, yyyy').format(_selectedStartDate!)} - ${DateFormat('MMMM d, yyyy').format(_selectedEndDate!)}',
                  style: const pw.TextStyle(fontSize: 14)),
            pw.Divider(),
            pw.ListView(
              children: events
                  .map((event) => pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${event.title} - ${event.address ?? 'No Location'}',
                            style: const pw.TextStyle(
                                fontSize: 16), // Removed bold
                          ),
                          pw.Text(
                              'Date: ${DateFormat('MMMM d, yyyy').format(event.date)}',
                              style: const pw.TextStyle(fontSize: 14)),
                          if (event.description?.isNotEmpty ?? false)
                            pw.Text('Description: ${event.description}',
                                style: const pw.TextStyle(fontSize: 14)),
                          pw.SizedBox(height: 10),
                          pw.Divider(),
                        ],
                      ))
                  .toList(),
            ),
          ];
        },
      ),
    );

    try {
      bool printed = await Printing.layoutPdf(
        onLayout: (_) => doc.save(),
      );
      if (printed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Events sent to print'),
            backgroundColor: accentColor,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (e.toString().contains('No printers available')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No printers available. Please connect a printer.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing events: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: const Text(
          'Print Events',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, color: primaryColor),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range, color: primaryColor),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.location_on, color: primaryColor),
            onPressed: _selectProperties,
            tooltip: 'Select Properties',
          ),
          DropdownButton<String>(
            value: _sortOption,
            icon: const Icon(Icons.sort, color: primaryColor),
            items: <String>['Date', 'Type']
                .map((String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value,
                          style: const TextStyle(color: primaryColor)),
                    ))
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                _sortOption = newValue!;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.print, color: primaryColor),
            onPressed: _printEvents,
            tooltip: 'Print Events',
          ),
        ],
        shadowColor: Colors.grey.withOpacity(0.2),
      ),
      body: Container(
        color: subtleColor,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _buildSearchField(),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('events').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final events = snapshot.data!.docs
                      .map((doc) => Event.fromFirestore(doc))
                      .toList();

                  var filteredEvents = events.where((event) {
                    bool matchesDateRange = _selectedStartDate == null ||
                        _selectedEndDate == null ||
                        (event.date.isAfter(_selectedStartDate!
                                .subtract(const Duration(days: 1))) &&
                            event.date.isBefore(_selectedEndDate!
                                .add(const Duration(days: 1))));
                    bool matchesProperties = _selectedProperties.isEmpty ||
                        _selectedProperties.contains(event.address);
                    bool matchesSearch = searchQuery.isEmpty ||
                        event.title
                            .toLowerCase()
                            .contains(searchQuery.toLowerCase()) ||
                        (event.description?.toLowerCase() ?? '')
                            .contains(searchQuery.toLowerCase());

                    return matchesDateRange &&
                        matchesProperties &&
                        matchesSearch;
                  }).toList();

                  // Apply sorting for the on-screen list
                  if (_sortOption == 'Date') {
                    filteredEvents.sort((a, b) => a.date.compareTo(b.date));
                  } else if (_sortOption == 'Type') {
                    filteredEvents.sort((a, b) => a.type
                        .toLowerCase()
                        .compareTo(b.type
                            .toLowerCase())); // Alphabetically by type (A-Z)
                  }

                  if (filteredEvents.isEmpty) {
                    return _buildEmptyState();
                  }

                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildEventsList(filteredEvents),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: subtleColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          labelText: 'Search Events',
          hintText: 'Search by title or description...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          labelStyle: TextStyle(color: primaryColor.withOpacity(0.7)),
          prefixIcon: const Icon(Icons.search, color: primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: subtleColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No Events Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            searchQuery.isEmpty &&
                    _selectedStartDate == null &&
                    _selectedEndDate == null &&
                    _selectedProperties.isEmpty
                ? 'No events available'
                : 'Try adjusting your filters or search terms',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<Event> events) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 100)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildEventCard(events[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventCard(Event event) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
            hoverColor: accentColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.event_note,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('EEE, MMM d, yyyy')
                                      .format(event.date),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            if (event.address != null &&
                                event.address != "No Address Selected") ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      event.address ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Type: ${event.type}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> initialSelected;

  const MultiSelectDialog({
    required this.items,
    required this.initialSelected,
    super.key,
  });

  @override
  _MultiSelectDialogState createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _selectedItems;

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Properties',
          style: TextStyle(color: primaryColor)),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: accentColor, width: 2),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: ListView(
          shrinkWrap: true,
          children: widget.items.map((item) {
            return CheckboxListTile(
              title: Text(item, style: const TextStyle(color: primaryColor)),
              value: _selectedItems.contains(item),
              checkColor: Colors.white,
              activeColor: accentColor,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedItems.add(item);
                  } else {
                    _selectedItems.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: primaryColor)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedItems),
          child: const Text('OK', style: TextStyle(color: primaryColor)),
        ),
      ],
    );
  }
}
