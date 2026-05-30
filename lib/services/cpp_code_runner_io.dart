import 'dart:async';
import 'dart:convert';
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

  Future<CppRunResult> run(String code, {String input = ''}) async {
    final batchResults = await runBatch(code, [input]);
    return batchResults.first;
  }

  Future<List<CppRunResult>> runBatch(String code, List<String> inputs) async {
    final compiler = await _findCompiler();
    if (compiler == null) {
      return List<CppRunResult>.filled(
        inputs.length,
        CppRunResult.error(
          'No C++ compiler found. Install g++ or clang++ and make sure it is available in PATH.',
        ),
        growable: false,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('sophia_cpp_');
    try {
      final compiled = await _compileExecutable(
        compiler: compiler,
        code: code,
        tempDir: tempDir,
      );

      if (compiled == null) {
        return List<CppRunResult>.filled(
          inputs.length,
          CppRunResult.error('Compilation failed.'),
          growable: false,
        );
      }

      final results = <CppRunResult>[];
      for (final input in inputs) {
        results.add(await _runExecutable(compiled.executable, input));
      }

      return results;
    } on TimeoutException catch (_) {
      return List<CppRunResult>.filled(
        inputs.length,
        CppRunResult.error('Program timed out.'),
        growable: false,
      );
    } on ProcessException catch (error) {
      return List<CppRunResult>.filled(
        inputs.length,
        CppRunResult.error(error.message),
        growable: false,
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<_CompiledExecutable?> _compileExecutable({
    required String compiler,
    required String code,
    required Directory tempDir,
  }) async {
    final sourceFile = File('${tempDir.path}${Platform.pathSeparator}main.cpp');
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
      throw ProcessException(
        compiler,
        const [],
        compileOutput.isEmpty
            ? 'Compilation failed with exit code ${compileResult.exitCode}.'
            : compileOutput,
        compileResult.exitCode,
      );
    }

    return _CompiledExecutable(executable: executable);
  }

  Future<CppRunResult> _runExecutable(File executable, String input) async {
    final process = await Process.start(
      executable.path,
      const [],
      workingDirectory: executable.parent.path,
    ).timeout(_runTimeout);

    try {
      if (input.isNotEmpty) {
        process.stdin.write(input);
      }

      await process.stdin.close();
    } on SocketException catch (_) {
      // The child process may exit before stdin is closed; keep reading output.
    }

    final stdoutText = await process.stdout.transform(utf8.decoder).join();
    final stderrText = await process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode;

    final combined = [
      stdoutText.trimRight(),
      stderrText.trimRight(),
    ].where((text) => text.isNotEmpty).join('\n');

    if (exitCode != 0) {
      return CppRunResult.error(
        combined.isEmpty
            ? 'Program exited with code $exitCode.'
            : '$combined\nProgram exited with code $exitCode.',
      );
    }

    return CppRunResult.success(
      combined.isEmpty ? 'Program finished with no output.' : combined,
    );
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

class _CompiledExecutable {
  final File executable;

  const _CompiledExecutable({required this.executable});
}
