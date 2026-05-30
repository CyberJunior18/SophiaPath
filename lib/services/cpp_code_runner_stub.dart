class CppRunResult {
  final String output;
  final bool isError;

  const CppRunResult({required this.output, required this.isError});

  factory CppRunResult.success(String output) {
    return CppRunResult(output: output, isError: false);
  }

  factory CppRunResult.error(String output) {
    return CppRunResult(output: output, isError: true);
  }
}

class CppCodeRunner {
  Future<CppRunResult> run(String code, {String input = ''}) async {
    return CppRunResult.error(
      'Running C++ code requires a local app build with g++ or clang++ installed.',
    );
  }

  Future<List<CppRunResult>> runBatch(String code, List<String> inputs) async {
    return List<CppRunResult>.filled(
      inputs.length,
      CppRunResult.error(
        'Running C++ code requires a local app build with g++ or clang++ installed.',
      ),
      growable: false,
    );
  }
}
