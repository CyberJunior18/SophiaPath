import 'cpp_code_runner.dart';
import 'java_code_runner.dart';

class CodeExecutionService {
  static final CodeExecutionService _instance =
      CodeExecutionService._internal();
  factory CodeExecutionService() => _instance;
  CodeExecutionService._internal();

  final CppCodeRunner _cppRunner = CppCodeRunner();
  final JavaCodeRunner _javaRunner = JavaCodeRunner();

  Future<Map<String, dynamic>> executeCode({
    required String language,
    required List<String> lines,
    String input = '',
  }) async {
    final code = lines.join('\n');

    switch (language.toLowerCase()) {
      case 'cpp':
      case 'c++':
        final result = await _cppRunner.run(code, input: input);
        return {
          'success': !result.isError,
          'output': result.output,
          'error': result.isError ? result.output : null,
        };

      case 'java':
        final result = await _javaRunner.run(code, input: input);
        return {
          'success': !result.isError,
          'output': result.output,
          'error': result.isError ? result.output : null,
        };

      default:
        return {
          'success': false,
          'output': null,
          'error': 'Unsupported language: $language',
        };
    }
  }

  Future<Map<String, dynamic>> executeBatch({
    required String language,
    required List<String> lines,
    required List<String> inputs,
  }) async {
    final code = lines.join('\n');

    switch (language.toLowerCase()) {
      case 'cpp':
      case 'c++':
        final results = await _cppRunner.runBatch(code, inputs);
        return {
          'success': true,
          'results': results
              .map((r) => {'output': r.output, 'isError': r.isError})
              .toList(),
        };

      case 'java':
        final results = await _javaRunner.runBatch(code, inputs);
        return {
          'success': true,
          'results': results
              .map((r) => {'output': r.output, 'isError': r.isError})
              .toList(),
        };

      default:
        return {'success': false, 'error': 'Unsupported language: $language'};
    }
  }
}
