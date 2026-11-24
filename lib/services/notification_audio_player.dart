enum NotificationSound {
  unauthorizedMovement,
  approvedMovementBeforeStart,
  activeTripConnectivityWarning,
  activeTripConnectivityRecovery,
  scheduledDepartureReminder,
  overdueDepartureWarning,
  synchronizationSuccess,
  synchronizationFailure,
}

abstract interface class NotificationAudioPlayer {
  Future<void> play(NotificationSound sound, double volume);
}
