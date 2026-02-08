import 'package:flutter/foundation.dart';
import '../models/app_state_snapshot.dart';

// Manages undo/redo history for the application
class UndoRedoService extends ChangeNotifier {
  // Maximum number of undo states to keep
  final int maxHistorySize;
  
  // Stack of previous states
  final List<AppStateSnapshot> _undoStack = [];
  
  // Stack of future states (for redo)
  final List<AppStateSnapshot> _redoStack = [];
  
  // Current state
  AppStateSnapshot? _currentState;
  
  UndoRedoService({this.maxHistorySize = 100});
  
  // Get current state
  AppStateSnapshot? get currentState => _currentState;
  
  // Check if undo is available
  bool get canUndo => _undoStack.isNotEmpty;
  
  // Check if redo is available
  bool get canRedo => _redoStack.isNotEmpty;
  
  // Get number of undo states available
  int get undoCount => _undoStack.length;
  
  // Get number of redo states available
  int get redoCount => _redoStack.length;
  
  // Get the last action description
  String? get lastActionDescription => _currentState?.actionDescription;
  
  // Push a new state to the undo stack
  void pushState(AppStateSnapshot newState) {
    // If we have a current state, push it to undo stack
    if (_currentState != null) {
      _undoStack.add(_currentState!);
      
      // Limit history size
      if (_undoStack.length > maxHistorySize) {
        _undoStack.removeAt(0);
      }
    }
    
    // Clear redo stack when a new action is performed
    _redoStack.clear();
    
    // Set new current state
    _currentState = newState;
    
    notifyListeners();
  }
  
  // Undo the last action
  AppStateSnapshot? undo() {
    if (!canUndo) return null;
    
    // Move current state to redo stack
    if (_currentState != null) {
      _redoStack.add(_currentState!);
    }
    
    // Pop from undo stack
    _currentState = _undoStack.removeLast();
    
    notifyListeners();
    
    return _currentState;
  }
  
  // Redo the last undone action
  AppStateSnapshot? redo() {
    if (!canRedo) return null;
    
    // Move current state to undo stack
    if (_currentState != null) {
      _undoStack.add(_currentState!);
      
      // Limit history size
      if (_undoStack.length > maxHistorySize) {
        _undoStack.removeAt(0);
      }
    }
    
    // Pop from redo stack
    _currentState = _redoStack.removeLast();
    
    notifyListeners();
    
    return _currentState;
  }
  
  // Clear all history
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _currentState = null;
    notifyListeners();
  }
  
  // Get a preview of what would be undone
  String? getUndoPreview() {
    if (!canUndo) return null;
    return _undoStack.last.actionDescription;
  }
  
  // Get a preview of what would be redone
  String? getRedoPreview() {
    if (!canRedo) return null;
    return _redoStack.last.actionDescription;
  }
}
