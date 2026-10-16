import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar_state.dart';

class AvatarController extends Notifier<AvatarState> {
  @override
  AvatarState build() => AvatarState.idle;

  void set(AvatarState next) => state = next;
}

final avatarProvider = NotifierProvider<AvatarController, AvatarState>(AvatarController.new);
