import 'dart:async';
import 'dart:io';

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
  static const Duration _compileTimeout = Duration(seconds: 10);
  static const Duration _runTimeout = Duration(seconds: 5);
  static const List<String> _compilers = ['g++', 'clang++'];

  Future<CppRunResult> run(String code) async {
    final compiler = await _findCompiler();
    if (compiler == null) {
      return CppRunResult.error(
        'No C++ compiler found. Install g++ or clang++ and make sure it is available in PATH.',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('sophia_cpp_');
    try {
      final sourceFile = File(
        '${tempDir.path}${Platform.pathSeparator}main.cpp',
      );
      final executable = File(
        '${tempDir.path}${Platform.pathSeparator}main${Platform.isWindows ? '.exe' : ''}',
      );

      await sourceFile.writeAsString(code);

      final compileResult = await Process.run(compiler, [
        '-std=c++17',
        '-O0',
        '-Wall',
        '-Wextra',
        sourceFile.path,
        '-o',
        executable.path,
      ], workingDirectory: tempDir.path).timeout(_compileTimeout);

      final compileOutput = _combinedOutput(compileResult);
      if (compileResult.exitCode != 0) {
        return CppRunResult.error(
          compileOutput.isEmpty
              ? 'Compilation failed with exit code ${compileResult.exitCode}.'
              : compileOutput,
        );
      }

      final runResult = await Process.run(
        executable.path,
        const [],
        workingDirectory: tempDir.path,
      ).timeout(_runTimeout);

      final runOutput = _combinedOutput(runResult);
      if (runResult.exitCode != 0) {
        return CppRunResult.error(
          runOutput.isEmpty
              ? 'Program exited with code ${runResult.exitCode}.'
              : '$runOutput\nProgram exited with code ${runResult.exitCode}.',
        );
      }

      return CppRunResult.success(
        runOutput.isEmpty ? 'Program finished with no output.' : runOutput,
      );
    } on TimeoutException catch (_) {
      return CppRunResult.error('Program timed out.');
    } on ProcessException catch (error) {
      return CppRunResult.error(error.message);
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<String?> _findCompiler() async {
    for (final compiler in _compilers) {
      try {
        final result = await Process.run(compiler, const [
          '--version',
        ]).timeout(const Duration(seconds: 2));
        if (result.exitCode == 0) return compiler;
      } catch (_) {}
    }

    return null;
  }

  String _combinedOutput(ProcessResult result) {
    final stdoutText = result.stdout.toString().trimRight();
    final stderrText = result.stderr.toString().trimRight();

    if (stdoutText.isEmpty) return stderrText;
    if (stderrText.isEmpty) return stdoutText;
    return '$stdoutText\n$stderrText';
  }
}
