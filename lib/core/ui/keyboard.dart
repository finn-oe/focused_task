import 'package:material_ui/material_ui.dart';

/// `onTapOutside` for every text field: tapping anywhere outside the field closes the on-screen keyboard.
///
/// Flutter's default only does this for mouse input; on phones a touch outside keeps the keyboard open, which can cover
/// buttons such as *Save* (#56). Tapping another text field is not "outside" (all fields share one tap region), so the
/// focus simply moves there.
void unfocusOnTapOutside(PointerDownEvent event) => FocusManager.instance.primaryFocus?.unfocus();
