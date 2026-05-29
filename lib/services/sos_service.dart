import 'package:shared_preferences/shared_preferences.dart';
import '../models/sos_contact.dart';

class SosService {
  static const String _contactsKey = 'sos_contacts_list';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<List<SosContact>> getContacts() async {
    try {
      final prefs = await _prefs;
      final List<String> contactsJson = prefs.getStringList(_contactsKey) ?? [];
      return contactsJson.map((jsonStr) => SosContact.fromJson(jsonStr)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveContacts(List<SosContact> contacts) async {
    try {
      final prefs = await _prefs;
      final List<String> contactsJson = contacts.map((c) => c.toJson()).toList();
      return await prefs.setStringList(_contactsKey, contactsJson);
    } catch (_) {
      return false;
    }
  }

  Future<bool> addContact(SosContact contact) async {
    final contacts = await getContacts();
    contacts.add(contact);
    return await saveContacts(contacts);
  }

  Future<bool> removeContact(String id) async {
    final contacts = await getContacts();
    contacts.removeWhere((c) => c.id == id);
    return await saveContacts(contacts);
  }
}
