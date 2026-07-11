import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/inline_code_text.dart';
import '../widgets/uml_diagram_widget.dart';
import '../models/course/lessonContent.dart';
import '../services/code_execution_service.dart';

class CodePlaygroundScreen extends StatefulWidget {
  final String title;
  final String initialCode;
  final String language;
  final List<dynamic>? testCases;
  final String challengeQuestion;
  final Map<String, dynamic>? challengeInfo;

  const CodePlaygroundScreen({
    super.key,
    required this.title,
    required this.initialCode,
    required this.language,
    this.testCases,
    this.challengeQuestion = '',
    this.challengeInfo,
  });

  @override
  State<CodePlaygroundScreen> createState() => _CodePlaygroundScreenState();
}

class _CodePlaygroundScreenState extends State<CodePlaygroundScreen> {
  late final CodePlaygroundController _codeController;
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _gutterScrollController = ScrollController();
  final ScrollController _terminalScrollController = ScrollController();
  final CodeExecutionService _codeExecutionService = CodeExecutionService();
  final TextEditingController _terminalInputController =
      TextEditingController();

  // Terminal state
  final StringBuffer _terminalBuffer = StringBuffer();
  bool _isCompiling = false;
  bool _isProcessRunning = false;
  bool _hasRunError = false;

  // Test results
  bool _testsPassed = false;
  int _passedTests = 0;
  int _totalTests = 0;
  List<_PlaygroundTestResult> _testResults = const [];

  // Process handles for interactive execution
  Process? _activeProcess;
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  @override
  void initState() {
    super.initState();
    _codeController = CodePlaygroundController(text: widget.initialCode);
    _editorScrollController.addListener(_syncScrollFromEditor);
    _gutterScrollController.addListener(_syncScrollFromGutter);
    _terminalAppendLine('Press ▶ Run to execute the code');
  }

  @override
  void dispose() {
    _killProcess();
    _editorScrollController
      ..removeListener(_syncScrollFromEditor)
      ..dispose();
    _gutterScrollController
      ..removeListener(_syncScrollFromGutter)
      ..dispose();
    _terminalScrollController.dispose();
    _codeController.dispose();
    _terminalInputController.dispose();
    super.dispose();
  }

  void _killProcess() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _activeProcess?.kill();
    _activeProcess = null;
    _stdoutSub = null;
    _stderrSub = null;
  }

  void _syncScrollFromEditor() {
    if (!_gutterScrollController.hasClients ||
        !_editorScrollController.hasClients) {
      return;
    }
    if (_gutterScrollController.offset == _editorScrollController.offset) {
      return;
    }
    _gutterScrollController.jumpTo(_editorScrollController.offset);
  }

  void _syncScrollFromGutter() {
    if (!_gutterScrollController.hasClients ||
        !_editorScrollController.hasClients) {
      return;
    }
    if (_editorScrollController.offset == _gutterScrollController.offset) {
      return;
    }
    _editorScrollController.jumpTo(_gutterScrollController.offset);
  }

  List<CodeChallengeTestCase> get _parsedTestCases {
    final rawTestCases = widget.testCases;
    if (rawTestCases == null || rawTestCases.isEmpty) return const [];

    if (rawTestCases.first is CodeChallengeTestCase) {
      return rawTestCases.cast<CodeChallengeTestCase>();
    }

    return rawTestCases
        .whereType<Map>()
        .map(
          (item) =>
              CodeChallengeTestCase.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  void _terminalAppend(String text) {
    _terminalBuffer.write(text);
  }

  void _terminalAppendLine(String line) {
    _terminalBuffer.writeln(line);
  }

  void _terminalClear() {
    _terminalBuffer.clear();
  }

  void _scrollTerminalToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runCode() async {
    final testCases = _parsedTestCases;

    // If there are test cases, use the batch execution (non-interactive)
    if (testCases.isNotEmpty) {
      if (_isCompiling) return;
      _terminalClear();
      _terminalAppendLine('Compiling and running tests...');
      setState(() {
        _hasRunError = false;
        _isCompiling = true;
        _isProcessRunning = false;
        _testsPassed = false;
        _passedTests = 0;
        _totalTests = testCases.length;
        _testResults = const [];
      });

      try {
        final inputs = testCases.map((tc) => tc.input).toList();
        final batchResult = await _codeExecutionService.executeBatch(
          language: widget.language,
          lines: _codeController.text.split('\n'),
          inputs: inputs,
        );
        if (!mounted) return;

        if (batchResult['success'] != true) {
          _terminalClear();
          _terminalAppendLine('Compilation failed:');
          _terminalAppend(batchResult['error']?.toString() ?? '');
          setState(() {
            _hasRunError = true;
            _isCompiling = false;
          });
          return;
        }

        final runResults = batchResult['results'] as List<dynamic>;
        final testResults = <_PlaygroundTestResult>[];
        var passed = 0;

        for (var i = 0; i < testCases.length; i++) {
          final tc = testCases[i];
          final rr = runResults[i] as Map<String, dynamic>;
          final actual = _normalizeOutput((rr['output'] ?? '').toString());
          final expected = _normalizeOutput(tc.expectedOutput);
          final ok = rr['isError'] != true && actual == expected;
          if (ok) passed++;
          testResults.add(
            _PlaygroundTestResult(
              index: i,
              testCase: tc,
              runResult: rr,
              passed: ok,
            ),
          );
        }

        setState(() {
          _passedTests = passed;
          _totalTests = testCases.length;
          _testsPassed = passed == testCases.length;
          _testResults = testResults;
          _hasRunError = !_testsPassed;
          _isCompiling = false;
        });
        _terminalClear();
        _terminalAppendLine('Passed $_passedTests/$_totalTests tests.');
      } catch (error) {
        if (!mounted) return;
        _terminalClear();
        _terminalAppendLine('Failed to run code: $error');
        setState(() {
          _hasRunError = true;
          _isCompiling = false;
        });
      }
      return;
    }

    // Interactive execution: compile once, then keep process alive
    if (_isProcessRunning) return; // Already running

    if (_activeProcess != null && !_isCompiling) {
      // Process already compiled, just restart it
      _killProcess();
    }

    _terminalClear();
    _terminalAppendLine('Compiling...');
    setState(() {
      _hasRunError = false;
      _isCompiling = true;
      _isProcessRunning = false;
    });

    try {
      final language = widget.language.toLowerCase();
      final code = _codeController.text;
      final executable = await _compileProgram(language, code);
      if (executable == null) {
        if (!mounted) return;
        setState(() {
          _hasRunError = true;
          _isCompiling = false;
        });
        return;
      }

      if (!mounted) return;

      // Start the process interactively
      final process = await Process.start(
        executable.path,
        [],
        workingDirectory: executable.parent.path,
      );

      _activeProcess = process;
      setState(() {
        _isCompiling = false;
        _isProcessRunning = true;
      });
      _terminalClear();

      // Listen to stdout in real-time
      _stdoutSub = process.stdout.transform(utf8.decoder).listen((data) {
        if (mounted) {
          _terminalAppend(data);
          _scrollTerminalToBottom();
          setState(() {});
        }
      });

      // Listen to stderr in real-time
      _stderrSub = process.stderr.transform(utf8.decoder).listen((data) {
        if (mounted) {
          _terminalAppend(data);
          _scrollTerminalToBottom();
          setState(() {});
        }
      });

      _scrollTerminalToBottom();

      // When process exits, clean up
      process.exitCode.then((code) {
        if (mounted) {
          setState(() {
            _isProcessRunning = false;
            _hasRunError = code != 0;
          });
          if (code != 0) {
            _terminalAppendLine('\nProcess exited with code $code.');
          }
        }
        _activeProcess = null;
      });
    } catch (error) {
      if (!mounted) return;
      _terminalAppendLine('Error: $error');
      setState(() {
        _hasRunError = true;
        _isCompiling = false;
        _isProcessRunning = false;
      });
    }
  }

  /// Compiles code and returns the executable File, or null on failure.
  Future<File?> _compileProgram(String language, String code) async {
    final tempDir = await Directory.systemTemp.createTemp('sophia_play_');

    try {
      if (language == 'cpp' || language == 'c++') {
        final compiler = await _findCppCompiler();
        if (compiler == null) {
          _terminalAppendLine('No C++ compiler found. Install g++ or clang++.');
          return null;
        }

        final sourceFile = File(
          '${tempDir.path}${Platform.pathSeparator}main.cpp',
        );
        await sourceFile.writeAsString(code);

        final executable = File(
          '${tempDir.path}${Platform.pathSeparator}main${Platform.isWindows ? '.exe' : ''}',
        );

        final compileResult = await Process.run(compiler, [
          '-std=c++17',
          '-O0',
          '-Wall',
          '-Wextra',
          sourceFile.path,
          '-o',
          executable.path,
        ], workingDirectory: tempDir.path).timeout(const Duration(seconds: 15));

        if (compileResult.exitCode != 0) {
          _terminalAppendLine(compileResult.stderr.toString().trimRight());
          return null;
        }

        return executable;
      } else if (language == 'java') {
        final className = _extractJavaClassName(code);
        if (className == null) {
          _terminalAppendLine('Could not find class name in Java code.');
          return null;
        }

        final sourceFile = File(
          '${tempDir.path}${Platform.pathSeparator}$className.java',
        );
        await sourceFile.writeAsString(code);

        final compileResult = await Process.run('javac', [
          sourceFile.path,
        ], workingDirectory: tempDir.path).timeout(const Duration(seconds: 15));

        if (compileResult.exitCode != 0) {
          _terminalAppendLine(compileResult.stderr.toString().trimRight());
          return null;
        }

        // Create a wrapper script to run the Java class
        return _createJavaRunner(tempDir, className);
      }
    } catch (e) {
      _terminalAppendLine('Compilation error: $e');
    }

    return null;
  }

  Future<File> _createJavaRunner(Directory tempDir, String className) async {
    final isWindows = Platform.isWindows;
    final scriptPath =
        '${tempDir.path}${Platform.pathSeparator}_run${isWindows ? '.bat' : '.sh'}';
    final scriptFile = File(scriptPath);

    final classNameEscaped = className;
    if (isWindows) {
      await scriptFile.writeAsString(
        '@echo off\r\ncd /d "%~dp0"\r\njava $classNameEscaped\r\n',
      );
    } else {
      await scriptFile.writeAsString(
        '#!/bin/sh\ncd "\$(dirname "\$0")"\nexec java "\$@" "$classNameEscaped"\n',
      );
      await Process.run('chmod', ['+x', scriptPath]);
    }

    return scriptFile;
  }

  Future<String?> _findCppCompiler() async {
    for (final compiler in ['g++', 'clang++']) {
      try {
        final result = await Process.run(compiler, [
          '--version',
        ]).timeout(const Duration(seconds: 2));
        if (result.exitCode == 0) return compiler;
      } catch (_) {}
    }
    return null;
  }

  String? _extractJavaClassName(String code) {
    final regex = RegExp(r'public\s+class\s+(\w+)');
    final match = regex.firstMatch(code);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    final fallback = RegExp(r'class\s+(\w+)');
    final fallbackMatch = fallback.firstMatch(code);
    if (fallbackMatch != null && fallbackMatch.groupCount >= 1) {
      return fallbackMatch.group(1);
    }
    return null;
  }

  void _submitTerminalInput() {
    final text = _terminalInputController.text;
    _terminalInputController.clear();

    // Echo the input in the terminal
    _terminalAppendLine(text);
    _scrollTerminalToBottom();

    if (_activeProcess != null) {
      try {
        _activeProcess!.stdin.writeln(text);
        _activeProcess!.stdin.flush();
      } catch (_) {}
      if (mounted) setState(() {});
    }
  }

  void _stopProcess() {
    _killProcess();
    _terminalAppendLine('\n[Process terminated]');
    setState(() {
      _isProcessRunning = false;
    });
  }

  String _normalizeOutput(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trimRight())
        .toList();

    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }

    return lines.join('\n').trim();
  }

  Widget _challengeSheetSection(
    BuildContext context,
    String title,
    String body,
    ColorScheme colorScheme,
  ) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          InlineCodeText(
            body,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeCodeBlock(
    BuildContext context,
    String label,
    String code,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTestResultCard(
    ThemeData theme,
    _PlaygroundTestResult result,
  ) {
    final borderColor = result.passed
        ? Colors.green.withValues(alpha: 0.3)
        : theme.colorScheme.error.withValues(alpha: 0.3);
    final tintColor = result.passed
        ? Colors.green.withValues(alpha: 0.08)
        : theme.colorScheme.error.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                result.passed ? Icons.check_circle : Icons.cancel,
                color: result.passed ? Colors.green : theme.colorScheme.error,
                size: 20,
              ),
            ],
          ),
          if (result.input.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Input',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                result.input,
                style: GoogleFonts.robotoMono(
                  fontSize: 12.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildOutputSidePanel(
                  theme: theme,
                  title: 'Expected',
                  content: result.expectedOutput,
                  backgroundColor: tintColor,
                  borderColor: borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutputSidePanel(
                  theme: theme,
                  title: 'Actual',
                  content: result.actualOutput,
                  backgroundColor: result.passed
                      ? Colors.green.withValues(alpha: 0.04)
                      : theme.colorScheme.error.withValues(alpha: 0.04),
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.passed ? 'Passed' : 'Failed',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: result.passed ? Colors.green : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSidePanel({
    required ThemeData theme,
    required String title,
    required String content,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content.isEmpty ? '(no output)' : content,
            style: GoogleFonts.robotoMono(
              fontSize: 12.5,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isBusy => _isCompiling || _isProcessRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final testCases = _parsedTestCases;

    return Scaffold(
      appBar: AppBar(
        title: InlineCodeText(widget.title, style: GoogleFonts.poppins()),
        backgroundColor: theme.colorScheme.primary,
        actions: [
          if (widget.challengeInfo != null)
            IconButton(
              tooltip: 'Challenge info',
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (sheetContext) {
                    final sheetColors = Theme.of(sheetContext).colorScheme;
                    final info = widget.challengeInfo!;
                    final example = info['example'] is Map
                        ? Map<String, dynamic>.from(info['example'] as Map)
                        : <String, dynamic>{};

                    return DraggableScrollableSheet(
                      initialChildSize: 0.65,
                      minChildSize: 0.4,
                      maxChildSize: 0.9,
                      expand: false,
                      builder: (_, scrollController) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: ListView(
                            controller: scrollController,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: sheetColors.onSurfaceVariant
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_cafe_outlined,
                                    color: sheetColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Code Challenge',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: sheetColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _challengeSheetSection(
                                sheetContext,
                                'Problem',
                                (info['problem'] ?? '').toString(),
                                sheetColors,
                              ),
                              _challengeSheetSection(
                                sheetContext,
                                'Input format',
                                (info['inputFormat'] ?? '').toString(),
                                sheetColors,
                              ),
                              _challengeSheetSection(
                                sheetContext,
                                'Output format',
                                (info['outputFormat'] ?? '').toString(),
                                sheetColors,
                              ),
                              _challengeSheetSection(
                                sheetContext,
                                'Constraints',
                                (info['constraints'] ?? '').toString(),
                                sheetColors,
                              ),
                              if (example.isNotEmpty) ...[
                                Text(
                                  'Example',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: sheetColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if ((example['input'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _challengeCodeBlock(
                                    sheetContext,
                                    'Input',
                                    (example['input'] ?? '').toString(),
                                    sheetColors,
                                  ),
                                if ((example['output'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  _challengeCodeBlock(
                                    sheetContext,
                                    'Output',
                                    (example['output'] ?? '').toString(),
                                    sheetColors,
                                  ),
                                if ((example['explanation'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      (example['explanation'] ?? '').toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        height: 1.5,
                                        color: sheetColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                              ],
                              // === UML DIAGRAM SECTION ===
                              if (info['umlDiagram'] is List &&
                                  (info['umlDiagram'] as List).isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Class Diagram',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: sheetColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...((info['umlDiagram'] as List).map((
                                  diagramData,
                                ) {
                                  final diagram = diagramData is Map
                                      ? Map<String, dynamic>.from(diagramData)
                                      : <String, dynamic>{};
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: UmlDiagramWidget(
                                      data: diagram,
                                      compact: true,
                                    ),
                                  );
                                })),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          if (_isProcessRunning)
            IconButton(
              tooltip: 'Stop process',
              onPressed: _stopProcess,
              icon: const Icon(Icons.stop_rounded),
            ),
          IconButton(
            tooltip: testCases.isNotEmpty ? 'Run tests' : 'Compile & run',
            onPressed: _isBusy ? null : _runCode,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _PlaygroundPanel(
                title: 'Code',
                child: _NumberedCodeEditor(
                  controller: _codeController,
                  editorScrollController: _editorScrollController,
                  gutterScrollController: _gutterScrollController,
                  theme: theme,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBusy
                    ? null
                    : testCases.isNotEmpty && _testsPassed
                    ? () => Navigator.pop(context, true)
                    : _runCode,
                icon: _isCompiling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : testCases.isNotEmpty && _testsPassed
                    ? const Icon(Icons.check_circle_outline)
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _isCompiling
                      ? 'Compiling...'
                      : _isProcessRunning
                      ? 'Running...'
                      : testCases.isNotEmpty && _testsPassed
                      ? 'Use This Solution'
                      : 'Run Code',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: testCases.isEmpty
                  ? _PlaygroundPanel(
                      title: 'Terminal',
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _terminalScrollController,
                              padding: const EdgeInsets.all(12),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: SelectableText(
                                  _terminalBuffer.toString().isEmpty
                                      ? 'Press ▶ Run to execute the code'
                                      : _terminalBuffer.toString(),
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: _hasRunError
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            height: 1,
                            color: theme.dividerColor.withValues(alpha: 0.35),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '❯',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 13,
                                    color: _isProcessRunning
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.35),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _terminalInputController,
                                    enabled: _isProcessRunning,
                                    maxLines: 1,
                                    textInputAction: TextInputAction.send,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: _isProcessRunning
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.35),
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                      hintText: _isProcessRunning
                                          ? 'Type input, press Enter to send'
                                          : 'Press ▶ Run',
                                      hintStyle: GoogleFonts.robotoMono(
                                        fontSize: 13,
                                        color: theme
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.65),
                                      ),
                                    ),
                                    onSubmitted: _isProcessRunning
                                        ? (_) => _submitTerminalInput()
                                        : null,
                                  ),
                                ),
                                if (_isProcessRunning)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        iconSize: 16,
                                        icon: const Icon(Icons.send_rounded),
                                        onPressed: _submitTerminalInput,
                                        tooltip: 'Send input',
                                        style: IconButton.styleFrom(
                                          foregroundColor:
                                              theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : _PlaygroundPanel(
                      title: 'Test Results',
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _terminalBuffer.toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _testsPassed
                                    ? Colors.green
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._testResults.map(
                              (r) => _buildSplitTestResultCard(theme, r),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaygroundTestResult {
  final int index;
  final CodeChallengeTestCase testCase;
  final Map<String, dynamic> runResult;
  final bool passed;

  const _PlaygroundTestResult({
    required this.index,
    required this.testCase,
    required this.runResult,
    required this.passed,
  });

  String get label =>
      testCase.hidden ? 'Hidden Test ${index + 1}' : 'Test ${index + 1}';
  String get input => testCase.input;
  String get expectedOutput => testCase.expectedOutput;
  String get actualOutput => (runResult['output'] ?? '').toString();
}

class _NumberedCodeEditor extends StatefulWidget {
  final CodePlaygroundController controller;
  final ScrollController editorScrollController;
  final ScrollController gutterScrollController;
  final ThemeData theme;

  const _NumberedCodeEditor({
    required this.controller,
    required this.editorScrollController,
    required this.gutterScrollController,
    required this.theme,
  });

  @override
  State<_NumberedCodeEditor> createState() => _NumberedCodeEditorState();
}

class _NumberedCodeEditorState extends State<_NumberedCodeEditor> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () => setState(() {});
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant _NumberedCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = widget.theme;
        final codeStyle = GoogleFonts.robotoMono(
          fontSize: 13,
          height: 1.45,
          color: theme.colorScheme.onSurface,
        );
        const gutterWidth = 25.0;
        const codeHorizontalPadding = 12.0 * 2;
        final availableWidth = max(
          0.0,
          constraints.maxWidth - gutterWidth - codeHorizontalPadding,
        );
        final gutterLabels = _buildGutterLabels(
          widget.controller.text,
          codeStyle,
          availableWidth,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: gutterWidth,
              child: ListView.builder(
                controller: widget.gutterScrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemExtent: 19,
                itemCount: gutterLabels.length,
                itemBuilder: (context, index) {
                  final label = gutterLabels[index];
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        label ?? '',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          height: 1.45,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 0),
            Expanded(
              child: TextField(
                controller: widget.controller,
                scrollController: widget.editorScrollController,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                cursorColor: theme.colorScheme.primary,
                style: codeStyle,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String?> _buildGutterLabels(
    String source,
    TextStyle style,
    double availableWidth,
  ) {
    final lines = source.isEmpty ? <String>[''] : source.split('\n');
    final labels = <String?>[];
    for (var i = 0; i < lines.length; i++) {
      final visualLineCount = _countWrappedVisualLines(
        lines[i],
        style,
        availableWidth,
      );
      labels.add('${i + 1}');
      for (var w = 1; w < visualLineCount; w++) {
        labels.add(null);
      }
    }
    return labels.isEmpty ? <String?>[null] : labels;
  }

  int _countWrappedVisualLines(
    String text,
    TextStyle style,
    double availableWidth,
  ) {
    if (availableWidth <= 0) return 1;
    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: availableWidth);
    return max(1, painter.computeLineMetrics().length);
  }
}

class CodePlaygroundController extends TextEditingController {
  CodePlaygroundController({super.text});

  static final RegExp _tokenPattern = RegExp(
    r'''(//.*$|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:#include|using|namespace|import|package|public|private|protected|class|static|void|int|double|float|char|boolean|String|return|if|else|for|while|do|switch|case|break|continue|new|this|super|extends|implements|interface|abstract|final|try|catch|throw|throws|true|false|null)\b|\b(?:cout|cin|std|endl|main|System|Scanner)\b|\b\d+(?:\.\d+)?\b|[{}()[\];,.<>+\-*/=])''',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return highlightedTextSpan(text, theme, baseStyle);
  }

  static TextSpan highlightedTextSpan(
    String source,
    ThemeData theme,
    TextStyle baseStyle,
  ) {
    final spans = <TextSpan>[];
    var lastMatchEnd = 0;
    for (final match in _tokenPattern.allMatches(source)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
      }
      final token = source.substring(match.start, match.end);
      spans.add(TextSpan(text: token, style: _styleForToken(token, theme)));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < source.length) {
      spans.add(TextSpan(text: source.substring(lastMatchEnd)));
    }
    return TextSpan(style: baseStyle, children: spans);
  }

  static TextStyle _styleForToken(String token, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    Color color;
    FontWeight fontWeight = FontWeight.w400;

    if (token.startsWith('//')) {
      color = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    } else if (token.startsWith('"') || token.startsWith("'")) {
      color = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    } else if (RegExp(r'^\d').hasMatch(token)) {
      color = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    } else if (RegExp(
      r'^(#include|using|namespace|import|package|public|private|protected|class|static|void|int|double|float|char|boolean|String|return|if|else|for|while|do|switch|case|break|continue|new|this|super|extends|implements|interface|abstract|final|try|catch|throw|throws|true|false|null)$',
    ).hasMatch(token)) {
      color = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
      fontWeight = FontWeight.w600;
    } else if (RegExp(
      r'^(cout|cin|std|endl|main|System|Scanner)$',
    ).hasMatch(token)) {
      color = isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26);
    } else {
      color = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
    }
    return TextStyle(color: color, fontWeight: fontWeight);
  }
}

class _PlaygroundPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _PlaygroundPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
