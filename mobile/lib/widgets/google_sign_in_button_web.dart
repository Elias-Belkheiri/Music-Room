import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget buildGoogleSignInPlatformButton({
  required double size,
  required VoidCallback onPressed,
  required Widget child,
}) {
  if (!kIsWeb && GoogleSignIn.instance.supportsAuthenticate()) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  // Web: the official GIS button (renderButton) MUST handle the click —
  // `authenticate()` throws UnimplementedError on web. But the GIS iframe
  // starts at 1x1 and only resizes once Google's script loads; if GIS is
  // blocked (ad-blocker, 3P cookies, popup blocker) the iframe stays tiny
  // and the circle looks dead. So wrap everything in an InkWell: taps that
  // land outside the iframe still fire onPressed (One Tap fallback + user
  // feedback), taps on the iframe go straight to Google.
  return InkWell(
    onTap: onPressed,
    borderRadius: BorderRadius.circular(size / 2),
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          SizedBox(
            width: size,
            height: size,
            child: web.renderButton(
              configuration: web.GSIButtonConfiguration(
                type: web.GSIButtonType.icon,
                shape: web.GSIButtonShape.pill,
                size: web.GSIButtonSize.large,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
