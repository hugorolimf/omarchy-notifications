// macOS-style notification banner. Pure presentational — no service,
// Notification, or ListModel references. The popup container drives lifetime.
//
// With Liquid Glass the card sits on a glass layer (namespace
// omarchy-notifications, set up by Service.qml) with the same theme tint and
// hairline as Glass Dock, so both read as one material; keep the fill alpha
// above the layer's mask_threshold. Without glass (glassBacked false) the
// plate is near-opaque so text stays readable over any window.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import "../NotificationLogic.js" as NotificationLogic

Item {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  // Nerd Font glyph used when no real icon is set (omarchy-notification-send -g).
  property string glyph: ""
  // NotificationUrgency: Low=0, Normal=1, Critical=2 (upstream).
  property int urgency: 1
  // Whether a Liquid Glass layer is behind the card (Service.qml probes it).
  property bool glassBacked: true
  property double timestamp: 0
  property int cornerRadius: 20

  // System monospace font injected by the container (only used for glyphs).
  property string fontFamily: ""

  readonly property bool hovered: hoverTracker.hovered

  signal closeRequested()
  signal cardClicked()

  readonly property string uiFont: "Adwaita Sans"
  readonly property color themeBg: Commons.Color.menu.background
  readonly property color themeText: Commons.Color.menu.text
  readonly property color textColor: themeText
  readonly property color secondaryColor: Qt.rgba(themeText.r, themeText.g, themeText.b, 0.78)
  readonly property color tertiaryColor: Qt.rgba(themeText.r, themeText.g, themeText.b, 0.5)

  // Resolve any icon reference to something that is known to load, or "".
  // Never hand Image an unchecked theme name: Qt's icon provider answers a
  // missing one with a pink/black checkerboard and still reports Ready.
  function resolveIcon(ref) {
    var value = String(ref || "")
    if (value.length === 0) return ""
    // Quickshell fills Notification.image with an unchecked image://icon/<name>
    // when the sender passed an icon name (notify-send -i).
    if (value.indexOf("image://icon/") === 0) return resolveIcon(value.slice(13))
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  function desktopEntryIcon() {
    void DesktopEntries.applications.values
    var candidates = [app, appIcon, String(app).toLowerCase()]
    for (var i = 0; i < candidates.length; i++) {
      if (!candidates[i]) continue
      var entry = DesktopEntries.heuristicLookup(candidates[i])
      if (entry && entry.icon) {
        var path = resolveIcon(entry.icon)
        if (path) return path
      }
    }
    return ""
  }

  function prettyAppName(name) {
    var value = String(name || "")
    if (value === "notify-send" || value === "omarchy-action" || value === "") return "Omarchy"
    var entry = DesktopEntries.heuristicLookup(value)
    if (entry && entry.name) return entry.name
    return value.charAt(0).toUpperCase() + value.slice(1)
  }

  readonly property string appIconSource: {
    var direct = resolveIcon(appIcon)
    if (direct) return direct
    var fromEntry = desktopEntryIcon()
    if (fromEntry) return fromEntry
    return resolveIcon(String(app).toLowerCase())
  }
  readonly property string imageSource: {
    var resolved = resolveIcon(image)
    return resolved === appIconSource ? "" : resolved
  }
  // macOS shows the sender's picture (avatar, cover art) in the icon slot with
  // the app icon as a small badge; otherwise just the app icon.
  readonly property string mainIconSource: imageSource.length > 0 ? imageSource : appIconSource
  readonly property bool showBadge: imageSource.length > 0 && appIconSource.length > 0
  readonly property bool hasGlyph: glyph.length > 0
  readonly property string sanitizedBody: NotificationLogic.sanitizeBody(body, app, appIcon)
  readonly property string styledBody: NotificationLogic.styledBody(body, app, appIcon)
  readonly property string displayApp: prettyAppName(app)
  // Title falls back to the app name so a body-only toast still has a heading.
  readonly property string titleText: summary.length > 0 ? summary : displayApp

  // "agora", "2 min", "1 h" — the macOS banner shows a relative time.
  property double now: Date.now()
  readonly property string timeText: {
    if (timestamp <= 0) return ""
    var minutes = Math.floor((now - timestamp) / 60000)
    if (minutes < 1) return "agora"
    if (minutes < 60) return minutes + " min"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + " h"
    return Qt.formatDate(new Date(timestamp), "dd/MM")
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.visible
    onTriggered: root.now = Date.now()
  }

  implicitWidth: 360
  implicitHeight: Math.max(68, content.implicitHeight + 26)

  HoverHandler { id: hoverTracker }

  // Glass tint: the theme's menu colour at the dock's translucency, a touch
  // denser so text stays readable over busy wallpapers.
  Rectangle {
    id: plate
    anchors.fill: parent
    radius: root.cornerRadius
    antialiasing: true
    color: root.urgency === 2
      ? Qt.rgba(0.55, 0.12, 0.1, root.glassBacked ? 0.42 : 0.92)
      : Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b,
                root.glassBacked ? (root.hovered ? 0.44 : 0.36) : (root.hovered ? 0.97 : 0.93))
    border.width: 1
    border.color: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.16)

    Behavior on color { ColorAnimation { duration: 160 } }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.closeRequested()
      else root.cardClicked()
    }
  }

  RowLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: 14
    anchors.rightMargin: 16
    spacing: 12

    Item {
      id: iconSlot
      Layout.preferredWidth: 38
      Layout.preferredHeight: 38
      Layout.alignment: Qt.AlignVCenter

      Image {
        id: mainIcon
        anchors.fill: parent
        source: root.mainIconSource
        sourceSize.width: 76 * Screen.devicePixelRatio
        sourceSize.height: 76 * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
        layer.enabled: root.imageSource.length > 0
        layer.smooth: true
      }

      // Fallback: an app-icon-like squircle in the accent colour with the
      // glyph, or a bell when there is nothing better to show.
      Rectangle {
        anchors.fill: parent
        radius: 10
        antialiasing: true
        visible: mainIcon.status !== Image.Ready
        gradient: Gradient {
          GradientStop { position: 0.0; color: root.urgency === 2 ? "#FF7A6E" : Qt.lighter(Commons.Color.accent, 1.25) }
          GradientStop { position: 1.0; color: root.urgency === 2 ? "#D93A2F" : Qt.darker(Commons.Color.accent, 1.15) }
        }
        border.width: 1
        border.color: "#33FFFFFF"

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: root.hasGlyph ? root.glyph : (root.urgency === 2 ? "󰀦" : "󰂚")
          color: "white"
          font.family: root.fontFamily
          font.pixelSize: 20
        }
      }

      Image {
        width: 18
        height: 18
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -4
        anchors.bottomMargin: -4
        visible: root.showBadge && status === Image.Ready
        source: root.showBadge ? root.appIconSource : ""
        sourceSize.width: 36 * Screen.devicePixelRatio
        sourceSize.height: 36 * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: 2

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
          // The spec defines the summary as single-line plain text; only the
          // body is StyledText (stripped in NotificationLogic).
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: root.titleText
          color: root.textColor
          font.family: root.uiFont
          font.pixelSize: 14
          font.weight: Font.DemiBold
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          textFormat: Text.PlainText
          visible: text.length > 0
          text: root.timeText
          color: root.tertiaryColor
          font.family: root.uiFont
          font.pixelSize: 12
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.sanitizedBody.length > 0
        text: root.styledBody
        textFormat: Text.StyledText
        color: root.secondaryColor
        linkColor: Commons.Color.accent
        font.family: root.uiFont
        font.pixelSize: 13
        lineHeight: 1.1
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: 4
      }
    }
  }

  // Close button: appears on hover over the top-left corner, as on macOS.
  Rectangle {
    id: closeButton
    width: 20
    height: 20
    radius: 10
    x: -6
    y: -6
    antialiasing: true
    opacity: root.hovered ? 1 : 0
    scale: root.hovered ? 1 : 0.6
    visible: opacity > 0
    color: closeArea.containsMouse
      ? Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b, 0.95)
      : Qt.rgba(root.themeBg.r, root.themeBg.g, root.themeBg.b, 0.82)
    border.width: 1
    border.color: Qt.rgba(root.themeText.r, root.themeText.g, root.themeText.b, 0.22)

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

    Text {
      anchors.centerIn: parent
      anchors.verticalCenterOffset: -1
      text: "×"
      color: root.textColor
      font.family: root.uiFont
      font.pixelSize: 15
      font.weight: Font.DemiBold
    }

    MouseArea {
      id: closeArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.closeRequested()
    }
  }
}
