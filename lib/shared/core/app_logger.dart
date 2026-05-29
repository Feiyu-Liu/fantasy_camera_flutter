void logAppError(String code, Object? message, [StackTrace? stackTrace]) {
  // ignore: avoid_print
  print('Error: $code${message == null ? '' : '\nError Message: $message'}');
  if (stackTrace != null) {
    // ignore: avoid_print
    print(stackTrace);
  }
}
