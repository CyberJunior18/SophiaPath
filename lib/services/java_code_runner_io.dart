import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  static const Duration _compileTimeout = Duration(seconds: 10);
  static const Duration _runTimeout = Duration(seconds: 5);
  static const String _javac = 'javac';
  static const String _java = 'java';

  Future<JavaRunResult> run(String code, {String input = ''}) async {
    final batchResults = await runBatch(code, [input]);
    return batchResults.first;
  }

  Future<List<JavaRunResult>> runBatch(String code, List<String> inputs) async {
    // Check if Java is installed
    if (!await _isJavaInstalled()) {
      return List<JavaRunResult>.filled(
        inputs.length,
        JavaRunResult.error(
          'Java compiler (javac) not found. Please install JDK and make sure it is available in PATH.',
        ),
        growable: false,
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('sophia_java_');
    try {
      // Extract the class name from the code
      final className = _extractClassName(code);
      if (className == null) {
        return List<JavaRunResult>.filled(
          inputs.length,
          JavaRunResult.error(
            'Could not find public class name in the code. Please ensure your code has a public class.',
          ),
          growable: false,
        );
      }

      // Write the Java source file
      final sourceFile = File(
        '${tempDir.path}${Platform.pathSeparator}$className.java',
      );
      await sourceFile.writeAsString(code);

      // Compile the Java code
      final compileError = await _compileJava(sourceFile, tempDir);
      if (compileError != null) {
        return List<JavaRunResult>.filled(
          inputs.length,
          JavaRunResult.error(compileError),
          growable: false,
        );
      }

      // Run the compiled code for each input
      final results = <JavaRunResult>[];
      for (final input in inputs) {
        results.add(await _runJavaClass(className, tempDir, input));
      }

      return results;
    } on TimeoutException catch (_) {
      return List<JavaRunResult>.filled(
        inputs.length,
        JavaRunResult.error('Program timed out.'),
        growable: false,
      );
    } on ProcessException catch (error) {
      return List<JavaRunResult>.filled(
        inputs.length,
        JavaRunResult.error(error.message),
        growable: false,
      );
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<bool> _isJavaInstalled() async {
    try {
      final result = await Process.run(_javac, [
        '-version',
      ]).timeout(const Duration(seconds: 2));
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  String? _extractClassName(String code) {
    // Look for public class declaration
    final regex = RegExp(r'public\s+class\s+(\w+)');
    final match = regex.firstMatch(code);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }

    // Fallback: look for any class declaration
    final fallbackRegex = RegExp(r'class\s+(\w+)');
    final fallbackMatch = fallbackRegex.firstMatch(code);
    if (fallbackMatch != null && fallbackMatch.groupCount >= 1) {
      return fallbackMatch.group(1);
    }

    return null;
  }

  Future<String?> _compileJava(File sourceFile, Directory tempDir) async {
    try {
      final compileResult = await Process.run(_javac, [
        sourceFile.path,
      ], workingDirectory: tempDir.path).timeout(_compileTimeout);

      final compileOutput = _combinedOutput(compileResult);
      if (compileResult.exitCode != 0) {
        return compileOutput.isEmpty
            ? 'Compilation failed with exit code ${compileResult.exitCode}.'
            : compileOutput;
      }

      return null; // null means success
    } catch (e) {
      return 'Compilation error: $e';
    }
  }

  Future<JavaRunResult> _runJavaClass(
    String className,
    Directory tempDir,
    String input,
  ) async {
    try {
      final process = await Process.start(_java, [
        className,
      ], workingDirectory: tempDir.path).timeout(_runTimeout);

      try {
        if (input.isNotEmpty) {
          process.stdin.write(input);
        }
        await process.stdin.close();
      } on SocketException catch (_) {
        // Child process may exit before stdin closes
      }

      final stdoutText = await process.stdout.transform(utf8.decoder).join();
      final stderrText = await process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      final combined = [
        stdoutText.trimRight(),
        stderrText.trimRight(),
      ].where((text) => text.isNotEmpty).join('\n');

      if (exitCode != 0) {
        return JavaRunResult.error(
          combined.isEmpty
              ? 'Program exited with code $exitCode.'
              : '$combined\nProgram exited with code $exitCode.',
        );
      }

      return JavaRunResult.success(
        combined.isEmpty ? 'Program finished with no output.' : combined,
      );
    } on TimeoutException {
      return JavaRunResult.error('Program execution timed out.');
    } catch (e) {
      return JavaRunResult.error('Error running program: $e');
    }
  }

  String _combinedOutput(ProcessResult result) {
    final stdoutText = result.stdout.toString().trimRight();
    final stderrText = result.stderr.toString().trimRight();

    if (stdoutText.isEmpty) return stderrText;
    if (stderrText.isEmpty) return stdoutText;
    return '$stdoutText\n$stderrText';
  }
}
