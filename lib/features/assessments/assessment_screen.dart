import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../data/assessment_data.dart';
import '../../data/assessment_service.dart';
import '../../router.dart';
import '../../theme/theme.dart';
import '../../ui/button.dart';
import '../../ui/illustration.dart';
import '../../ui/progress_line.dart';
import '../../ui/top_bar.dart';

class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  AssessmentAccess? _access;
  AssessmentSession? _session;
  String? _error;
  bool _busy = false;

  AssessmentService? get _svc => ref.read(assessmentServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = _svc;
    if (svc == null) return;
    try {
      final access = await svc.access();
      AssessmentSession? session;
      if (access.activeSessionId != null) {
        session = await svc.get(access.activeSessionId!);
      }
      if (!mounted) return;
      setState(() {
        _access = access;
        _session = session;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _start() async {
    final svc = _svc;
    if (svc == null) return;
    setState(() => _busy = true);
    try {
      final session = await svc.start();
      if (!mounted) return;
      setState(() {
        _session = session;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  Future<void> _send(Future<AssessmentSession> Function() work) async {
    setState(() => _busy = true);
    try {
      final session = await work();
      if (!mounted) return;
      setState(() {
        _session = session;
        _busy = false;
      });
      if (session.status == 'passed' || session.status == 'failed') {
        ref.invalidate(assessmentAccessProvider);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    final session = _session;
    return Scaffold(
      backgroundColor: IqColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            IqTopBar(
              variant: IqTopBarVariant.page,
              title: assessmentIntro.title,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: access == null
                  ? const Center(child: CircularProgressIndicator())
                  : access.state == 'passed' || session?.status == 'passed'
                  ? _Done(
                      title: 'You’re in',
                      body: 'You can start new briefs.',
                      action: 'See briefs',
                      onTap: () => context.go(Routes.home),
                    )
                  : access.state == 'unavailable' || session?.status == 'failed'
                  ? _Done(
                      title: 'New challenges are currently unavailable.',
                      body: 'Your earlier briefs are still here.',
                      action: 'My submissions',
                      onTap: () => context.go(Routes.submissions),
                    )
                  : session?.question != null
                  ? _Question(
                      session: session!,
                      busy: _busy,
                      onAnswer: (i) => _send(() => _svc!.answer(session.id, i)),
                      onSkip: () => _send(() => _svc!.skip(session.id)),
                    )
                  : _Intro(error: _error, busy: _busy, onStart: _start),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart, required this.busy, this.error});

  final VoidCallback onStart;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IqSpace.s4,
        IqSpace.s2,
        IqSpace.s4,
        IqSpace.s4,
      ),
      child: Column(
        children: [
          const Spacer(),
          const IqFigure(IqFigures.writer, width: 188, arrive: true),
          const SizedBox(height: IqSpace.s5),
          Text(
            assessmentIntro.title,
            textAlign: TextAlign.center,
            style: IqText.display,
          ),
          const SizedBox(height: IqSpace.s3),
          Text(
            assessmentIntro.body,
            textAlign: TextAlign.center,
            style: IqText.body.copyWith(color: IqColors.fg2),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: IqSpace.s3),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: IqText.small.copyWith(color: IqColors.err),
              ),
            ),
          const Spacer(),
          IqButton(
            label: 'Start',
            width: double.infinity,
            loading: busy,
            onTap: busy ? null : onStart,
          ),
        ],
      ),
    );
  }
}

class _Question extends StatefulWidget {
  const _Question({
    required this.session,
    required this.busy,
    required this.onAnswer,
    required this.onSkip,
  });

  final AssessmentSession session;
  final bool busy;
  final ValueChanged<int> onAnswer;
  final VoidCallback onSkip;

  @override
  State<_Question> createState() => _QuestionState();
}

class _QuestionState extends State<_Question> {
  int? _picked;
  late int _left;
  Timer? _timer;

  AssessmentQuestion get q => widget.session.question!;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(_Question old) {
    super.didUpdateWidget(old);
    if (old.session.question?.index != q.index) {
      _picked = null;
      _arm();
    }
  }

  void _arm() {
    _timer?.cancel();
    _left = q.remainingMs;
    final end = DateTime.now().millisecondsSinceEpoch + q.remainingMs;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final left = end - DateTime.now().millisecondsSinceEpoch;
      if (!mounted) return;
      setState(() => _left = left < 0 ? 0 : left);
      if (left <= 0) {
        _timer?.cancel();
        if (!widget.busy) widget.onSkip();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_left / 1000).ceil();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              IqSpace.s4,
              IqSpace.s3,
              IqSpace.s4,
              IqSpace.s4,
            ),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${q.index + 1} of ${q.total}', style: IqText.small),
                  Text('${seconds}s', style: IqText.small),
                ],
              ),
              const SizedBox(height: IqSpace.s2),
              IqProgressLine(value: (q.index + 1) / q.total),
              const SizedBox(height: IqSpace.s4),
              Text(q.prompt, style: IqText.title),
              if (q.svg != null) ...[
                const SizedBox(height: IqSpace.s3),
                SvgPicture.string(q.svg!, fit: BoxFit.contain),
              ],
              const SizedBox(height: IqSpace.s4),
              for (final option in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: IqSpace.s2),
                  child: IqButton(
                    label: option.text,
                    kind: _picked == option.index
                        ? IqButtonKind.primary
                        : IqButtonKind.secondary,
                    width: double.infinity,
                    onTap: () => setState(() => _picked = option.index),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            IqSpace.s4,
            0,
            IqSpace.s4,
            IqSpace.s4,
          ),
          child: Row(
            children: [
              IqButton(
                label: 'Skip',
                kind: IqButtonKind.ghost,
                onTap: widget.busy ? null : widget.onSkip,
              ),
              const SizedBox(width: IqSpace.s2),
              Expanded(
                child: IqButton(
                  label: 'Next',
                  loading: widget.busy,
                  onTap: _picked == null || widget.busy
                      ? null
                      : () => widget.onAnswer(_picked!),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.title,
    required this.body,
    required this.action,
    required this.onTap,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(IqSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: IqText.display),
          const SizedBox(height: IqSpace.s3),
          Text(body, style: IqText.body.copyWith(color: IqColors.fg2)),
          const Spacer(),
          IqButton(label: action, width: double.infinity, onTap: onTap),
        ],
      ),
    );
  }
}
