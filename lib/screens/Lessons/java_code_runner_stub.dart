class JavaRunResult {
  final String output;
  final bool isError;

  const JavaRunResult({required this.output, required this.isError});

  factory JavaRunResult.success(String output) {
    return JavaRunResult(output: output, isError: false);
  }

  factory JavaRunResult.error(String output) {
    return JavaRunResult(output: output, isError: true);
  }
}

class JavaCodeRunner {
  Future<JavaRunResult> run(String code, {String input = ''}) async {
    return JavaRunResult.error(
      'Running Java code requires a local app build with JDK installed.',
    );
  }

  Future<List<JavaRunResult>> runBatch(String code, List<String> inputs) async {
    return List<JavaRunResult>.filled(
      inputs.length,
      JavaRunResult.error(
        'Running Java code requires a local app build with JDK installed.',
      ),
      growable: false,
    );
  }
}
