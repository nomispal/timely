import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class AddressService {
  final String _baseUrl = "https://nominatim.openstreetmap.org/search";
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch suggestions from both Firebase and OpenStreetMap
  Future<List<String>> getAddressSuggestions(String query) async {
    List<String> suggestions = [];

    // Fetch saved addresses from Firebase
    try {
      final querySnapshot = await _firestore
          .collection('saved_addresses')
          .orderBy('timestamp', descending: true) // Most recent first
          .limit(5) // Limit to avoid overload
          .get();
      final savedAddresses = querySnapshot.docs
          .map((doc) => doc['address'] as String)
          .where((address) =>
              query.isEmpty ||
              address.toLowerCase().contains(query.toLowerCase()))
          .toList();
      suggestions.addAll(savedAddresses);
    } catch (e) {
      print('Error fetching saved addresses: $e');
    }

    // Fetch from OpenStreetMap API
    try {
      final response = await http.get(
        Uri.parse("$_baseUrl?q=$query&format=json&addressdetails=1&limit=5"),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final apiSuggestions =
            data.map((item) => item['display_name'] as String).toList();
        // Add API suggestions, avoiding duplicates with saved addresses
        for (var suggestion in apiSuggestions) {
          if (!suggestions.contains(suggestion)) {
            suggestions.add(suggestion);
          }
        }
      } else {
        throw Exception('Failed to load address suggestions from API');
      }
    } catch (e) {
      print('Error fetching API suggestions: $e');
    }

    return suggestions.take(5).toList(); // Limit to 5 total suggestions
  }

  // Save a new address to Firebase
  Future<void> saveAddress(String address) async {
    try {
      await _firestore.collection('saved_addresses').add({
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Address saved to Firebase: $address');
    } catch (e) {
      print('Error saving address: $e');
    }
  }
}
