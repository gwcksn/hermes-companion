import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gateway/chat_controller.dart';
import '../theme/tokens.dart';
import '../widgets/bubbles.dart';
import '../widgets/common.dart';
import '../widgets/icons.dart';
import 'home_shell.dart';
import 'listening_screen.dart';

/// Chat page: the ongoing companion conversation for the selected profile.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(text);
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final ctl = ref.read(chatProvider.notifier);
    final canStop = chat.busy && _input.text.trim().isEmpty && chat.clarify == null;
    // While the streaming bubble is still empty, its status sits beside it in
    // the same row, so the separate activity line below stays hidden.
    final inlineStatus =
        chat.messages.isNotEmpty &&
        chat.messages.last.role == ChatRole.hermes &&
        chat.messages.last.streaming &&
        chat.messages.last.text.isEmpty;

    // The soft keyboard leaves ~63dp; below that the 10dp gap above the composer goes.
    return LayoutBuilder(
      builder: (context, box) {
        final tight = box.maxHeight < 120;
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  if (chat.messages.isEmpty) return _EmptyState(chat.phase);
                  final items = chat.messages.reversed.toList();
                  return ListView.separated(
                    reverse: true,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final m = items[i];
                      final status = m.role == ChatRole.hermes && m.streaming && m.text.isEmpty
                          ? switch (chat.activity) {
                              'Working on it…' => 'working on it',
                              'Looking it up…' => 'looking it up',
                              _ => 'thinking on it',
                            }
                          : null;
                      return _MessageView(m, width: c.maxWidth, status: status);
                    },
                  );
                },
              ),
            ),
            if ((chat.activity != null && !inlineStatus) || chat.phase == ChatPhase.offline && chat.messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    chat.activity ?? 'Offline. Reconnecting…',
                    style: hText(
                      13,
                      weight: FontWeight.w600,
                      color: chat.activity != null ? HColors.mint : HColors.coral,
                    ),
                  ),
                ),
              ),
            if (chat.approval != null) ...[
              const SizedBox(height: 8),
              _ApprovalCard(chat.approval!, onAnswer: ctl.answerApproval),
            ] else if (chat.clarify?.current != null) ...[
              const SizedBox(height: 8),
              _ClarifyCard(chat.clarify!.current!, onPick: ctl.answerClarify, onSkip: ctl.skipClarify),
            ],
            SizedBox(height: tight ? 0 : 10),
            SizedBox(
              height: 48,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextField(
                        controller: _input,
                        style: hText(15, weight: FontWeight.w600),
                        cursorColor: HColors.mint,
                        textAlignVertical: TextAlignVertical.center,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          hintText: chat.clarify != null ? 'Type your answer' : 'Message Hermes',
                          isDense: true,
                          filled: true,
                          fillColor: HColors.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.transparent, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: Colors.transparent, width: 2),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: HColors.mint, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canStop)
                    RoundIconButton(
                      icon: HIcon.stop,
                      iconColor: HColors.coral,
                      background: HColors.surface,
                      semanticLabel: 'Stop Hermes',
                      iconSize: 18,
                      onPressed: ctl.stop,
                    )
                  else
                    RoundIconButton(
                      icon: HIcon.arrowRight,
                      iconColor: HColors.peach,
                      background: HColors.surface,
                      semanticLabel: 'Send message',
                      onPressed: _submit,
                    ),
                  const SizedBox(width: 8),
                  RoundIconButton(
                    icon: HIcon.mic,
                    iconColor: HColors.onMint,
                    background: HColors.mint,
                    semanticLabel: 'Talk to Hermes',
                    onPressed: () => Navigator.of(context).push(fadeRoute(const ListeningScreen())),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.phase);

  final ChatPhase phase;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (phase) {
      ChatPhase.ready => ('Say something to Hermes', HColors.muted),
      ChatPhase.offline => ('Offline. Reconnecting…', HColors.coral),
      _ => ('Connecting to Hermes…', HColors.muted),
    };
    return Center(
      child: Text(
        text,
        style: hText(15, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView(this.m, {required this.width, this.status});

  final ChatMessage m;
  final double width;

  /// Live status shown beside the empty typing bubble (e.g. "working on it").
  final String? status;

  @override
  Widget build(BuildContext context) {
    if (status != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TextBubble(text: '…', fromUser: false, maxWidth: width * 0.84),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              status!,
              style: hText(13, weight: FontWeight.w600, color: HColors.mint),
            ),
          ),
        ],
      );
    }
    return switch (m.role) {
      ChatRole.user => TextBubble(text: m.text, fromUser: true, maxWidth: width * 0.76),
      ChatRole.hermes => TextBubble(text: m.text.isEmpty ? '…' : m.text, fromUser: false, maxWidth: width * 0.84),
      ChatRole.note => Center(
        child: Text(
          m.text,
          textAlign: TextAlign.center,
          style: hText(13, weight: FontWeight.w600, color: m.error ? HColors.coral : HColors.muted),
        ),
      ),
    };
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(color: HColors.surfaceActive, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard(this.a, {required this.onAnswer});

  final ApprovalPrompt a;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final summary = a.command.isNotEmpty ? a.command : a.description;
    return _Card(
      children: [
        Text('Hermes wants to run', style: hText(13, color: HColors.amber)),
        const SizedBox(height: 4),
        Text(
          summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: HColors.text, height: 1.3),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _SmallPill('Deny', bg: HColors.surface, fg: HColors.coral, onTap: () => onAnswer('deny')),
            const SizedBox(width: 8),
            _SmallPill('Allow once', bg: HColors.peach, fg: HColors.onPeach, onTap: () => onAnswer('once')),
          ],
        ),
      ],
    );
  }
}

class _ClarifyCard extends StatelessWidget {
  const _ClarifyCard(this.q, {required this.onPick, required this.onSkip});

  final ClarifyQuestion q;
  final ValueChanged<String?> onPick;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        Text(
          q.question,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: hText(15, color: HColors.text, height: 1.3),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final choice in q.choices) ...[
                _SmallPill(choice, bg: HColors.mint, fg: HColors.onMint, onTap: () => onPick(choice)),
                const SizedBox(width: 8),
              ],
              _SmallPill('Skip', bg: HColors.surface, fg: HColors.muted, onTap: onSkip),
            ],
          ),
        ),
      ],
    );
  }
}

/// 36dp pill used inside cards (the card itself keeps the 44dp row height budget).
class _SmallPill extends StatelessWidget {
  const _SmallPill(this.label, {required this.bg, required this.fg, required this.onTap});

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(label, style: hText(14, color: fg)),
        ),
      ),
    );
  }
}
