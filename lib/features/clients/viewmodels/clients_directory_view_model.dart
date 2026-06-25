import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/clients_directory_repository.dart';
import '../models/client_directory_entry.dart';

class ClientsDirectoryViewModel extends ChangeNotifier {
  ClientsDirectoryViewModel({required ClientsDirectoryRepository repository})
    : _repository = repository;

  final ClientsDirectoryRepository _repository;

  final List<ClientDirectoryEntry> _clients = [];
  String searchQuery = '';
  bool isLoading = false;
  String? errorMessage;
  Timer? _searchDebounce;

  List<ClientDirectoryEntry> get clients => List.unmodifiable(_clients);

  List<ClientDirectoryEntry> get filteredClients {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return clients;
    }

    return clients.where((client) {
      return client.fullName.toLowerCase().contains(query) ||
          client.documentNumber.endsWith(query) ||
          client.maskedDocument.toLowerCase().contains(query) ||
          client.businessName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _repository.fetchDirectory();
      _clients
        ..clear()
        ..addAll(fetched);
    } catch (error) {
      errorMessage = 'No se pudo cargar el directorio de clientes.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      searchQuery = value;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
