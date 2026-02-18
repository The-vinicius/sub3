import 'dart:io';
import '../models/sub.dart';
import '../services/database_service.dart';

class DatabaseExample {
  final DatabaseService _databaseService = DatabaseService.instance;

  // Example: Save a new Sub
  Future<void> saveSubExample() async {
    try {
      // Create a new Sub object
      final sub = Sub(
        'Example Subtitle',
        File('/path/to/subtitle.srt'),
        File('/path/to/audio.mp3'),
      );

      // Save to database
      final id = await _databaseService.saveSub(sub);
      print('Sub saved with ID: $id');
    } catch (e) {
      print('Error saving sub: $e');
    }
  }

  // Example: Get all Subs
  Future<void> getAllSubsExample() async {
    try {
      final subs = await _databaseService.getAllSubs();
      print('Found ${subs.length} subs:');
      for (final sub in subs) {
        print('- ${sub.name} (ID: ${sub.id})');
      }
    } catch (e) {
      print('Error getting subs: $e');
    }
  }

  // Example: Get Sub by ID
  Future<void> getSubByIdExample(int id) async {
    try {
      final sub = await _databaseService.getSubById(id);
      if (sub != null) {
        print('Found sub: ${sub.name}');
      } else {
        print('Sub with ID $id not found');
      }
    } catch (e) {
      print('Error getting sub by ID: $e');
    }
  }

  // Example: Update Sub
  Future<void> updateSubExample(int id) async {
    try {
      final existingSub = await _databaseService.getSubById(id);
      if (existingSub != null) {
        // Create updated version
        final updatedSub = existingSub.copyWith(
          name: 'Updated ${existingSub.name}',
        );

        // Update in database
        final rowsAffected = await _databaseService.updateSub(id, updatedSub);
        print('Updated $rowsAffected rows');
      }
    } catch (e) {
      print('Error updating sub: $e');
    }
  }

  // Example: Delete Sub
  Future<void> deleteSubExample(int id) async {
    try {
      final rowsAffected = await _databaseService.deleteSub(id);
      print('Deleted $rowsAffected rows');
    } catch (e) {
      print('Error deleting sub: $e');
    }
  }

  // Example: Complete workflow
  Future<void> completeWorkflowExample() async {
    try {
      print('=== Database Workflow Example ===');

      // 1. Save a new sub
      final sub1 = Sub('Test Sub 1', File('/test1.srt'), File('/test1.mp3'));
      final id1 = await _databaseService.saveSub(sub1);
      print('Saved sub with ID: $id1');

      final sub2 = Sub('Test Sub 2', File('/test2.srt'), File('/test2.mp3'));
      final id2 = await _databaseService.saveSub(sub2);
      print('Saved sub with ID: $id2');

      // 2. Get all subs
      final allSubs = await _databaseService.getAllSubs();
      print('Total subs: ${allSubs.length}');

      // 3. Get specific sub
      final retrievedSub = await _databaseService.getSubById(id1);
      if (retrievedSub != null) {
        print('Retrieved: ${retrievedSub.name}');
      }

      // 4. Update sub
      final updatedSub = retrievedSub!.copyWith(name: 'Updated Test Sub 1');
      await _databaseService.updateSub(id1, updatedSub);
      print('Updated sub $id1');

      // 5. Delete sub
      await _databaseService.deleteSub(id2);
      print('Deleted sub $id2');

      // 6. Final count
      final finalSubs = await _databaseService.getAllSubs();
      print('Final subs count: ${finalSubs.length}');

    } catch (e) {
      print('Error in workflow: $e');
    }
  }
} 