import 'dart:async';
import 'package:flutter/material.dart';
import '../services/address_service.dart';

class AddressAutocomplete extends StatefulWidget {
  final void Function(String) onAddressSelected;

  const AddressAutocomplete({super.key, required this.onAddressSelected});

  @override
  _AddressAutocompleteState createState() => _AddressAutocompleteState();
}

class _AddressAutocompleteState extends State<AddressAutocomplete> {
  final AddressService _addressService = AddressService();
  final TextEditingController _controller = TextEditingController();
  List<String> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSuggestions(); // Load saved addresses on init
  }

  void _loadInitialSuggestions() {
    setState(() => _isLoading = true);
    _addressService.getAddressSuggestions('').then((results) {
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isLoading = false;
        });
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    });
  }

  void _onTextChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _isLoading = true);
      _addressService.getAddressSuggestions(value).then((results) {
        if (mounted) {
          setState(() {
            _suggestions = results;
            _isLoading = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Enter Address',
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black)),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey)),
                ),
                onChanged: _onTextChanged,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _addressService.saveAddress(value); // Save custom input
                    widget.onAddressSelected(value);
                  }
                },
              ),
              const SizedBox(height: 10),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  height: 200, // Limit height for scrollable list
                  child: ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_suggestions[index]),
                        onTap: () {
                          _addressService.saveAddress(
                              _suggestions[index]); // Save selected suggestion
                          widget.onAddressSelected(_suggestions[index]);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
