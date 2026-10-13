# Android export checklist

The user exports and installs the app. Check these settings in your own export preset/template:

- Allow **INTERNET**, **CAMERA**, and **VIBRATE** permissions. Camera permission also needs runtime approval when capture is implemented.
- Enable the **Native Camera Plugin** for export, as well as in Project Settings → Plugins.
- Allow plain HTTP to the LAN server: `android:usesCleartextTraffic='true'` or the equivalent in your template/network security configuration.
- Pixel 6a uses 64-bit ARM; **arm64-v8a** alone is sufficient.
- The phone is probably running Android 16 (API 36); confirm with the debug device report. Apps targeting API 36 always draw edge to edge on Android 16, so verify safe-area handling around the status bar, camera cutout and gesture bar on the phone.
- Check the export's **target SDK** and whether **predictive back** is enabled. These affect delivery of Android back actions. Test both gesture navigation and three-button navigation.
- Back currently quits from the main menu and returns to the menu from Capture or Results. Confirmation dialogs come in Prompt 13.

The exact Godot 4.6.3 setting is `application/config/quit_on_go_back=false`. The Router autoload handles `NOTIFICATION_WM_GO_BACK_REQUEST`; Godot propagates that notification through the root window's children, including autoload nodes. See the [4.6.3 startup source](https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp) and [window notification source](https://github.com/godotengine/godot/blob/4.6.3-stable/scene/main/window.cpp).

See Android's [Android 16 behavior changes](https://developer.android.com/about/versions/16/behavior-changes-16) for edge-to-edge and predictive-back behavior.
