import 'package:hive_flutter/hive_flutter.dart';
import '../models/lead.dart';
import 'storage_service.dart';

/// Backward-compatible HiveService proxy delegating directly to StorageService
class HiveService {
  static final HiveService instance = HiveService._internal();
  HiveService._internal();

  StorageService get _storage => StorageService.instance;

  Box<dynamic> get leadsBox => _storage.leadsBox;
  Box<dynamic> get settingsBox => _storage.settingsBox;
  Box<dynamic> get blacklistBox => _storage.blacklistBox;

  Future<void> init() async {
    await _storage.init();
  }

  bool leadExists(String companyName, String rawPhone) =>
      _storage.leadExists(companyName, rawPhone);

  bool isBlacklisted(String rawPhone) => _storage.isBlacklisted(rawPhone);

  Future<bool> addLead(Lead lead) => _storage.addLead(lead);

  Future<void> updateLead(Lead lead) => _storage.updateLead(lead);

  Future<void> deleteLead(String id) => _storage.deleteLead(id);

  List<Lead> getAllLeads() => _storage.getAllLeads();

  Lead? getLeadById(String id) => _storage.getLeadById(id);

  Future<void> addActivity(String leadId, LeadActivity activity) =>
      _storage.addActivity(leadId, activity);

  Future<void> updateLeadStatus(String leadId, String newStatus) =>
      _storage.updateLeadStatus(leadId, newStatus);

  Future<void> setFollowUpDate(String leadId, String? followUpDate) =>
      _storage.setFollowUpDate(leadId, followUpDate);

  Future<Lead?> markLeadContacted(String leadId) =>
      _storage.markLeadContacted(leadId);

  Future<void> blacklistContact({
    required String rawPhone,
    required String reason,
    String? companyName,
    String? leadId,
  }) =>
      _storage.blacklistContact(
        rawPhone: rawPhone,
        reason: reason,
        companyName: companyName,
        leadId: leadId,
      );

  String exportToCsv() => _storage.exportToCsv();

  String generatePipelineExecutiveBriefing() =>
      _storage.generatePipelineExecutiveBriefing();

  String? getApiKey() => _storage.getApiKey();

  Future<void> saveApiKey(String key) => _storage.saveApiKey(key);

  Future<void> seedInitialCorporateLeads() =>
      _storage.seedInitialCorporateLeads();
}
