import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "fx-rates"

  property string baseCurrency: setting("base", "USD")
  property string quoteCurrency: setting("quote", "EUR")
  property string timeframe: setting("timeframe", "1M")

  property real currentRate: 0.0
  property real changePercent: 0.0
  property real change: 0.0
  property bool isUp: true
  property string latestDate: ""
  property var timeSeriesData: null
  property bool loading: false
  property string errorMessage: ""

  readonly property string displayRate: currentRate > 0 ? Model.formatRate(currentRate) : "..."
  readonly property string displayPair: baseCurrency + "/" + quoteCurrency
  readonly property string trendArrow: currentRate > 0 ? (isUp ? "▲" : "▼") : ""

  readonly property color trendColor: isUp ? "#2ecc71" : "#e74c3c"

  function fetchRates() {
    if (fetchProc.running) return
    loading = true
    errorMessage = ""
    var startDate = Model.getStartDateString(root.timeframe)
    var url = "https://api.frankfurter.dev/v1/" + startDate + "..?base=" + root.baseCurrency + "&symbols=" + root.quoteCurrency
    fetchProc.command = ["curl", "-fsS", "--max-time", "6", url]
    fetchProc.running = true
  }

  function updateConfig(newBase, newQuote, newTimeframe) {
    if (newBase === newQuote) return
    var b = newBase || root.baseCurrency
    var q = newQuote || root.quoteCurrency
    var tf = newTimeframe || root.timeframe

    root.baseCurrency = b
    root.quoteCurrency = q
    root.timeframe = tf

    var entry = {
      id: root.moduleName,
      base: b,
      quote: q,
      timeframe: tf
    }
    root.settings = entry

    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }

    injectPanel()
    fetchRates()
  }

  function swapCurrencies() {
    updateConfig(root.quoteCurrency, root.baseCurrency, root.timeframe)
  }

  function setTimeframe(tf) {
    updateConfig(root.baseCurrency, root.quoteCurrency, tf)
  }

  // --- Popout shape contract for Omarchy bar ---
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("baseCurrency" in target) target.baseCurrency = root.baseCurrency
    if ("quoteCurrency" in target) target.quoteCurrency = root.quoteCurrency
    if ("timeframe" in target) target.timeframe = root.timeframe
    if ("timeSeriesData" in target) target.timeSeriesData = root.timeSeriesData
    if ("currentRate" in target) target.currentRate = root.currentRate
    if ("changePercent" in target) target.changePercent = root.changePercent
    if ("change" in target) target.change = root.change
    if ("isUp" in target) target.isUp = root.isUp
    if ("latestDate" in target) target.latestDate = root.latestDate
    if ("loading" in target) target.loading = root.loading
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: {
    var b = setting("base", "")
    var q = setting("quote", "")
    var tf = setting("timeframe", "")
    if (b && b !== baseCurrency) baseCurrency = b
    if (q && q !== quoteCurrency) quoteCurrency = q
    if (tf && tf !== timeframe) timeframe = tf
    injectPanel()
  }

  Component.onCompleted: {
    fetchRates()
  }

  Process {
    id: fetchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.loading = false
        var raw = String(text || "").trim()
        if (!raw) {
          root.errorMessage = "Failed to fetch exchange rates"
          return
        }
        var res = Model.parseTimeSeries(raw, root.quoteCurrency)
        if (res.success) {
          root.timeSeriesData = res
          root.currentRate = res.currentRate
          root.changePercent = res.changePercent
          root.change = res.change
          root.isUp = res.isUp
          root.latestDate = res.latestDate
          root.errorMessage = ""
          root.injectPanel()
        } else {
          root.errorMessage = res.error || "Parsing error"
        }
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (fetchProc.exitCode !== 0 && !root.timeSeriesData) {
          root.loading = false
          root.errorMessage = "Network error"
        }
      }
    }
  }

  // Refresh every 10 minutes automatically
  Timer {
    interval: 600000
    running: true
    repeat: true
    onTriggered: root.fetchRates()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "fx-rates"
    function refresh(): void { root.fetchRates() }
    function swap(): void { root.swapCurrencies() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : (root.displayPair + " " + root.displayRate + " " + root.trendArrow)
    labelVisible: !root.vertical
    hasVisualContent: true
    tooltipText: root.baseCurrency + "/" + root.quoteCurrency + ": " + Model.formatPreciseRate(root.currentRate)
      + "\n" + Model.formatChange(root.change, root.changePercent)
      + "\nToggle: Super+Alt+X (or tap)"
      + "\nControls: [←/→] Scrub · [S]wap · [R]efresh · [1-4] Time · [N/P] Pairs · [Esc] Close"

    onPressed: function(b) {
      root.togglePanel()
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      OpticalGlyph {
        width: button.width
        height: Style.bar.iconSlot
        text: root.baseCurrency
        fontFamily: button.fontFamily
        fontSize: button.fontSize * 0.8
        color: button.foreground
      }

      OpticalGlyph {
        width: button.width
        height: Style.bar.iconSlot
        text: root.quoteCurrency
        fontFamily: button.fontFamily
        fontSize: button.fontSize * 0.8
        color: button.foreground
      }

      OpticalGlyph {
        width: button.width
        height: Style.bar.iconSlot
        text: root.displayRate
        fontFamily: button.fontFamily
        fontSize: button.fontSize * 0.75
        color: root.trendColor
      }
    }
  }
}
