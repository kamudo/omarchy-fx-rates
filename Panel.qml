import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "fx-rates"
  ipcTarget: "fx-rates"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property string baseCurrency: hostWidget ? hostWidget.baseCurrency : "USD"
  property string quoteCurrency: hostWidget ? hostWidget.quoteCurrency : "EUR"
  property string timeframe: hostWidget ? hostWidget.timeframe : "1M"

  property real currentRate: hostWidget ? hostWidget.currentRate : 0.0
  property real changePercent: hostWidget ? hostWidget.changePercent : 0.0
  property real change: hostWidget ? hostWidget.change : 0.0
  property bool isUp: hostWidget ? hostWidget.isUp : true
  property string latestDate: hostWidget ? hostWidget.latestDate : ""
  property var timeSeriesData: hostWidget ? hostWidget.timeSeriesData : null
  property bool loading: hostWidget ? hostWidget.loading : false

  property var hoveredPoint: null
  property real convertAmount: 100.0
  property bool showAllCurrencies: false

  readonly property real activeRate: hoveredPoint ? hoveredPoint.rate : currentRate
  readonly property string activeDate: hoveredPoint ? hoveredPoint.date : latestDate
  readonly property real activeChange: {
    if (!timeSeriesData || !timeSeriesData.points || timeSeriesData.points.length === 0) return 0.0
    var baseVal = timeSeriesData.points[0].rate
    return activeRate - baseVal
  }
  readonly property real activeChangePercent: {
    if (!timeSeriesData || !timeSeriesData.points || timeSeriesData.points.length === 0) return 0.0
    var baseVal = timeSeriesData.points[0].rate
    return baseVal > 0 ? (activeChange / baseVal) * 100 : 0.0
  }
  readonly property bool activeIsUp: activeChange >= 0
  readonly property color activeTrendColor: activeIsUp ? "#2ecc71" : "#e74c3c"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dimColor: Qt.darker(foreground, 1.45)
  readonly property color surfaceColor: Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var currencyOptions: {
    var opts = []
    for (var i = 0; i < Model.CURRENCIES.length; i++) {
      var c = Model.CURRENCIES[i]
      opts.push({ value: c.code, label: c.code + " (" + c.symbol + ") " + c.name })
    }
    return opts
  }

  function refresh() {
    if (hostWidget && hostWidget.fetchRates) hostWidget.fetchRates()
  }

  function swap() {
    if (hostWidget && hostWidget.swapCurrencies) hostWidget.swapCurrencies()
  }

  function selectPair(base, quote) {
    if (hostWidget && hostWidget.updateConfig) hostWidget.updateConfig(base, quote, root.timeframe)
  }

  function selectTimeframe(tf) {
    if (hostWidget && hostWidget.setTimeframe) hostWidget.setTimeframe(tf)
  }

  function stepChart(dx) {
    var pts = (root.timeSeriesData && root.timeSeriesData.points) ? root.timeSeriesData.points : []
    if (pts.length < 2) return
    var currentIdx = pts.length - 1
    if (root.hoveredPoint && root.hoveredPoint.idx !== undefined) {
      currentIdx = root.hoveredPoint.idx
    }
    var nextIdx = Math.max(0, Math.min(pts.length - 1, currentIdx + dx))
    root.hoveredPoint = {
      idx: nextIdx,
      date: pts[nextIdx].date,
      rate: pts[nextIdx].rate
    }
    if (chartCanvas) chartCanvas.requestPaint()
  }

  function cyclePair(direction) {
    var pairs = Model.POPULAR_PAIRS
    var currentIdx = -1
    for (var i = 0; i < pairs.length; i++) {
      if (pairs[i].base === root.baseCurrency && pairs[i].quote === root.quoteCurrency) {
        currentIdx = i
        break
      }
    }
    var nextIdx = 0
    if (currentIdx === -1) {
      nextIdx = direction > 0 ? 0 : pairs.length - 1
    } else {
      nextIdx = ((currentIdx + direction) % pairs.length + pairs.length) % pairs.length
    }
    root.selectPair(pairs[nextIdx].base, pairs[nextIdx].quote)
  }

  onTimeSeriesDataChanged: {
    if (chartCanvas) chartCanvas.requestPaint()
  }

  onOpenedChanged: {
    if (opened) {
      hoveredPoint = null
      if (hostWidget && hostWidget.fetchRates) hostWidget.fetchRates()
      Qt.callLater(function() {
        if (keyCatcher) keyCatcher.forceActiveFocus()
        if (chartCanvas) chartCanvas.requestPaint()
      })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(690))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: amountInput.activeFocus

      onCloseRequested: root.close()

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.stepChart(dx)
        }
        if (dy !== 0) {
          flickable.contentY = Math.max(0, Math.min(flickable.contentHeight - flickable.height, flickable.contentY + dy * Style.space(48)))
        }
      }

      onTextKey: function(t) {
        if (t === "r" || t === "R") {
          root.refresh()
        } else if (t === "s" || t === "S") {
          root.swap()
        } else if (t === "1") {
          root.selectTimeframe("7D")
        } else if (t === "2") {
          root.selectTimeframe("1M")
        } else if (t === "3") {
          root.selectTimeframe("3M")
        } else if (t === "4") {
          root.selectTimeframe("1Y")
        } else if (t === "n" || t === "N") {
          root.cyclePair(1)
        } else if (t === "p" || t === "P") {
          root.cyclePair(-1)
        } else if (t === "c" || t === "C") {
          amountInput.forceActiveFocus()
          amountInput.selectAll()
        } else if (t === "a" || t === "A") {
          root.showAllCurrencies = !root.showAllCurrencies
        } else if (t === "q" || t === "Q") {
          root.close()
        }
      }

      Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: mainColumn
          width: flickable.width
          spacing: Style.space(12)

          // ==========================================
          // SECTION 1: HERO HEADER (Rate, Change, Actions)
          // ==========================================
          Item {
            width: parent.width
            implicitHeight: heroLeft.implicitHeight

            Column {
              id: heroLeft
              anchors.left: parent.left
              anchors.right: heroRight.left
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(4)

              Row {
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText
                  text: root.baseCurrency + "/" + root.quoteCurrency
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  anchors.verticalCenter: parent.verticalCenter
                }

                // Trend Pill
                Rectangle {
                  height: Style.space(20)
                  width: trendText.implicitWidth + Style.space(14)
                  radius: height / 2
                  color: Qt.rgba(root.activeTrendColor.r, root.activeTrendColor.g, root.activeTrendColor.b, 0.16)
                  border.color: Qt.rgba(root.activeTrendColor.r, root.activeTrendColor.g, root.activeTrendColor.b, 0.35)
                  border.width: 1
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    id: trendText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: (root.activeIsUp ? "▲ " : "▼ ") + Model.formatChange(root.activeChange, root.activeChangePercent)
                    color: root.activeTrendColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              // Big Exchange Rate
              Text {
                textFormat: Text.PlainText
                text: "1 " + root.baseCurrency + " = " + Model.formatPreciseRate(root.activeRate) + " " + root.quoteCurrency
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title || Style.space(22)
                font.bold: true
              }

              // Date / Subtitle
              Text {
                textFormat: Text.PlainText
                text: root.hoveredPoint
                  ? ("Selected: " + Model.formatDateFull(root.hoveredPoint.date))
                  : ("ECB Reference Rate · " + (root.latestDate ? Model.formatDateFull(root.latestDate) : "Updating..."))
                color: root.hoveredPoint ? root.activeTrendColor : root.dimColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            // Action Buttons: Swap and Refresh
            Row {
              id: heroRight
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Button {
                text: "⇄"
                tooltipText: "Swap currencies (S)"
                bordered: true
                fontSize: Style.font.body
                onClicked: root.swap()
              }

              Button {
                iconText: "󰑐"
                iconSpinning: root.loading
                tooltipText: "Refresh rates (R)"
                bordered: true
                fontSize: Style.font.body
                onClicked: root.refresh()
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ==========================================
          // SECTION 2: TIMEFRAME SELECTOR
          // ==========================================
          Row {
            id: timeframeRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real btnWidth: (width - spacing * 3) / 4

            Repeater {
              model: [
                { label: "7D [1]", id: "7D" },
                { label: "1M [2]", id: "1M" },
                { label: "3M [3]", id: "3M" },
                { label: "1Y [4]", id: "1Y" }
              ]

              Button {
                required property var modelData
                width: timeframeRow.btnWidth
                text: modelData.label
                selected: root.timeframe === modelData.id
                bordered: true
                fontSize: Style.font.bodySmall
                onClicked: root.selectTimeframe(modelData.id)
              }
            }
          }

          // ==========================================
          // SECTION 3: HISTORICAL RATE CHART
          // ==========================================
          BorderSurface {
            id: chartBox
            width: parent.width
            height: Style.space(170)
            radius: Style.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
            borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)

            Canvas {
              id: chartCanvas
              anchors.fill: parent
              anchors.margins: Style.space(4)
              antialiasing: true

              readonly property var points: (root.timeSeriesData && root.timeSeriesData.points) ? root.timeSeriesData.points : []

              onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                if (!points || points.length < 2) {
                  ctx.fillStyle = root.dimColor
                  ctx.font = "12px sans-serif"
                  ctx.textAlign = "center"
                  ctx.fillText(root.loading ? "Loading rate data..." : "No historical data available", width / 2, height / 2)
                  return
                }

                var padLeft = 14
                var padRight = 54
                var padTop = 18
                var padBottom = 26
                var plotW = width - padLeft - padRight
                var plotH = height - padTop - padBottom

                var minR = root.timeSeriesData.minRate
                var maxR = root.timeSeriesData.maxRate
                var span = maxR - minR
                if (span <= 0) span = maxR * 0.01 || 0.001
                var yMin = minR - span * 0.08
                var yMax = maxR + span * 0.08
                var yRange = yMax - yMin

                function toX(i) {
                  return padLeft + (i / (points.length - 1)) * plotW
                }
                function toY(val) {
                  return padTop + plotH - ((val - yMin) / yRange) * plotH
                }

                // --- 1. Draw horizontal grid lines & labels ---
                var gridLevels = [
                  { val: maxR, label: Model.formatRate(maxR) },
                  { val: (maxR + minR) / 2, label: Model.formatRate((maxR + minR) / 2) },
                  { val: minR, label: Model.formatRate(minR) }
                ]

                ctx.lineWidth = 1
                ctx.font = "10px " + (root.fontFamily ? root.fontFamily : "sans-serif")
                ctx.textAlign = "left"

                for (var g = 0; g < gridLevels.length; g++) {
                  var gy = toY(gridLevels[g].val)
                  ctx.strokeStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                  ctx.beginPath()
                  ctx.setLineDash([4, 4])
                  ctx.moveTo(padLeft, gy)
                  ctx.lineTo(padLeft + plotW, gy)
                  ctx.stroke()
                  ctx.setLineDash([])

                  ctx.fillStyle = root.dimColor
                  ctx.fillText(gridLevels[g].label, padLeft + plotW + 6, gy + 3)
                }

                // --- 2. Gradient area fill under curve ---
                var fillGrad = ctx.createLinearGradient(0, padTop, 0, padTop + plotH)
                var lineColor = root.activeTrendColor
                fillGrad.addColorStop(0.0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.28))
                fillGrad.addColorStop(0.85, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.04))
                fillGrad.addColorStop(1.0, Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.0))

                ctx.beginPath()
                ctx.moveTo(toX(0), padTop + plotH)
                ctx.lineTo(toX(0), toY(points[0].rate))
                for (var k = 1; k < points.length; k++) {
                  var px = toX(k - 1)
                  var py = toY(points[k - 1].rate)
                  var cx = toX(k)
                  var cy = toY(points[k].rate)
                  var mx = (px + cx) / 2
                  ctx.bezierCurveTo(mx, py, mx, cy, cx, cy)
                }
                ctx.lineTo(toX(points.length - 1), padTop + plotH)
                ctx.closePath()
                ctx.fillStyle = fillGrad
                ctx.fill()

                // --- 3. Main rate curve stroke ---
                ctx.beginPath()
                ctx.moveTo(toX(0), toY(points[0].rate))
                for (var j = 1; j < points.length; j++) {
                  var prevX = toX(j - 1)
                  var prevY = toY(points[j - 1].rate)
                  var currX = toX(j)
                  var currY = toY(points[j].rate)
                  var midX = (prevX + currX) / 2
                  ctx.bezierCurveTo(midX, prevY, midX, currY, currX, currY)
                }
                ctx.strokeStyle = lineColor
                ctx.lineWidth = 2.2
                ctx.lineJoin = "round"
                ctx.stroke()

                // --- 4. Date labels along bottom ---
                ctx.fillStyle = root.dimColor
                ctx.font = "10px " + (root.fontFamily ? root.fontFamily : "sans-serif")
                ctx.textAlign = "left"
                ctx.fillText(Model.formatDateShort(points[0].date), padLeft, height - 6)

                ctx.textAlign = "center"
                var midIdx = Math.floor(points.length / 2)
                ctx.fillText(Model.formatDateShort(points[midIdx].date), toX(midIdx), height - 6)

                ctx.textAlign = "right"
                ctx.fillText(Model.formatDateShort(points[points.length - 1].date), padLeft + plotW, height - 6)

                // --- 5. Hover/Keyboard cursor & highlight dot ---
                if (root.hoveredPoint && root.hoveredPoint.idx >= 0 && root.hoveredPoint.idx < points.length) {
                  var hx = toX(root.hoveredPoint.idx)
                  var hy = toY(points[root.hoveredPoint.idx].rate)

                  // Vertical dashed guide line
                  ctx.strokeStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.55)
                  ctx.lineWidth = 1
                  ctx.setLineDash([3, 3])
                  ctx.beginPath()
                  ctx.moveTo(hx, padTop)
                  ctx.lineTo(hx, padTop + plotH)
                  ctx.stroke()
                  ctx.setLineDash([])

                  // Outer glow circle
                  ctx.beginPath()
                  ctx.arc(hx, hy, 7, 0, 2 * Math.PI)
                  ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.4)
                  ctx.fill()

                  // Inner solid dot
                  ctx.beginPath()
                  ctx.arc(hx, hy, 3.5, 0, 2 * Math.PI)
                  ctx.fillStyle = lineColor
                  ctx.fill()
                }
              }
            }

            MouseArea {
              id: chartMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.CrossCursor

              function updateHover(mx) {
                var pts = (root.timeSeriesData && root.timeSeriesData.points) ? root.timeSeriesData.points : []
                if (pts.length < 2) return
                var padLeft = 14
                var padRight = 54
                var plotW = width - padLeft - padRight
                var clampedX = Math.max(0, Math.min(plotW, mx - padLeft))
                var fraction = clampedX / plotW
                var idx = Math.round(fraction * (pts.length - 1))
                idx = Math.max(0, Math.min(pts.length - 1, idx))

                root.hoveredPoint = {
                  idx: idx,
                  date: pts[idx].date,
                  rate: pts[idx].rate
                }
                chartCanvas.requestPaint()
              }

              onPositionChanged: function(mouse) { updateHover(mouse.x) }
              onExited: {
                root.hoveredPoint = null
                chartCanvas.requestPaint()
              }
            }
          }

          // ==========================================
          // SECTION 4: STATS METRICS ROW
          // ==========================================
          Row {
            id: statsRow
            width: parent.width
            spacing: Style.space(8)

            readonly property real colWidth: (width - spacing * 3) / 4

            StatBox {
              width: statsRow.colWidth
              title: "LOW"
              value: root.timeSeriesData ? Model.formatRate(root.timeSeriesData.minRate) : "—"
              foreground: root.foreground
              dim: root.dimColor
              fontFamily: root.fontFamily
            }

            StatBox {
              width: statsRow.colWidth
              title: "AVERAGE"
              value: root.timeSeriesData ? Model.formatRate(root.timeSeriesData.avgRate) : "—"
              foreground: root.foreground
              dim: root.dimColor
              fontFamily: root.fontFamily
            }

            StatBox {
              width: statsRow.colWidth
              title: "HIGH"
              value: root.timeSeriesData ? Model.formatRate(root.timeSeriesData.maxRate) : "—"
              foreground: root.foreground
              dim: root.dimColor
              fontFamily: root.fontFamily
            }

            StatBox {
              width: statsRow.colWidth
              title: "RANGE"
              value: root.timeSeriesData ? Model.formatRate(root.timeSeriesData.maxRate - root.timeSeriesData.minRate) : "—"
              foreground: root.foreground
              dim: root.dimColor
              fontFamily: root.fontFamily
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ==========================================
          // SECTION 5: QUICK PAIR PRESETS & SELECTOR
          // ==========================================
          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(headerText.implicitHeight, toggleBtn.implicitHeight)

              PanelSectionHeader {
                id: headerText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "POPULAR PAIRS (N: Next, P: Prev)"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Button {
                id: toggleBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.showAllCurrencies ? "Hide list ▲ [A]" : "All currencies ▼ [A]"
                fontSize: Style.font.caption
                bordered: false
                onClicked: root.showAllCurrencies = !root.showAllCurrencies
              }
            }

            // Quick Pair Chips
            Flow {
              width: parent.width
              spacing: Style.space(5)

              Repeater {
                model: Model.POPULAR_PAIRS

                Button {
                  required property var modelData
                  text: modelData.base + "/" + modelData.quote
                  selected: root.baseCurrency === modelData.base && root.quoteCurrency === modelData.quote
                  bordered: true
                  fontSize: Style.font.caption
                  onClicked: root.selectPair(modelData.base, modelData.quote)
                }
              }
            }

            // Expandable Full Currency Pickers
            Row {
              visible: root.showAllCurrencies
              width: parent.width
              spacing: Style.space(8)

              Dropdown {
                id: baseDropdown
                label: "Base Currency"
                value: root.baseCurrency
                options: root.currencyOptions
                width: (parent.width - Style.space(8)) / 2
                onChanged: function(val) {
                  if (val === root.quoteCurrency) root.swap()
                  else root.selectPair(val, root.quoteCurrency)
                }
              }

              Dropdown {
                id: quoteDropdown
                label: "Target Currency"
                value: root.quoteCurrency
                options: root.currencyOptions
                width: (parent.width - Style.space(8)) / 2
                onChanged: function(val) {
                  if (val === root.baseCurrency) root.swap()
                  else root.selectPair(root.baseCurrency, val)
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ==========================================
          // SECTION 6: QUICK CONVERTER CALCULATOR
          // ==========================================
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "QUICK CONVERTER (Press [C] to type amount)"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: amountInput
                width: Style.space(110)
                text: "100"
                font.bold: true
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: 0; decimals: 4 }
                onTextChanged: {
                  var val = parseFloat(text)
                  root.convertAmount = (isFinite(val) && val >= 0) ? val : 0.0
                }
                Keys.onEscapePressed: {
                  amountInput.focus = false
                  keyCatcher.forceActiveFocus()
                }
                Keys.onReturnPressed: {
                  amountInput.focus = false
                  keyCatcher.forceActiveFocus()
                }
                Keys.onEnterPressed: {
                  amountInput.focus = false
                  keyCatcher.forceActiveFocus()
                }
              }

              Text {
                textFormat: Text.PlainText
                text: root.baseCurrency
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: "="
                color: root.dimColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                textFormat: Text.PlainText
                text: Model.formatRate(root.convertAmount * root.currentRate) + " " + root.quoteCurrency
                color: root.activeTrendColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // ==========================================
          // SECTION 7: KEYBOARD SHORTCUTS LEGEND
          // ==========================================
          Flow {
            width: parent.width
            spacing: Style.space(8)

            KeyBadge { keyText: "S"; labelText: "Swap" }
            KeyBadge { keyText: "R"; labelText: "Refresh" }
            KeyBadge { keyText: "←/→"; labelText: "Scrub" }
            KeyBadge { keyText: "1-4"; labelText: "Time" }
            KeyBadge { keyText: "N/P"; labelText: "Pairs" }
            KeyBadge { keyText: "C"; labelText: "Convert" }
            KeyBadge { keyText: "A"; labelText: "Currencies" }
            KeyBadge { keyText: "Esc"; labelText: "Close" }
          }
        }
      }
    }
  }

  // --- Sub-component: StatBox for Metrics Row ---
  component StatBox: BorderSurface {
    id: statBox
    property string title: ""
    property string value: ""
    property color foreground: Color.foreground
    property color dim: Qt.darker(foreground, 1.45)
    property string fontFamily: Style.font.family

    implicitHeight: Style.space(48)
    radius: Style.cornerRadius
    color: Qt.rgba(statBox.foreground.r, statBox.foreground.g, statBox.foreground.b, 0.04)
    borderSpec: Border.controlSpec("normal", statBox.foreground, Color.accent)

    Column {
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: statBox.title
        color: statBox.dim
        font.family: statBox.fontFamily
        font.pixelSize: Style.font.caption * 0.85
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: statBox.value
        color: statBox.foreground
        font.family: statBox.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  // --- Sub-component: KeyBadge for Keyboard Shortcuts Legend ---
  component KeyBadge: Row {
    id: keyBadge
    property string keyText: ""
    property string labelText: ""
    spacing: Style.space(4)

    Rectangle {
      height: Style.space(18)
      width: Math.max(height, kLabel.implicitWidth + Style.space(8))
      radius: Style.space(3)
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)
      border.width: 1
      anchors.verticalCenter: parent.verticalCenter

      Text {
        id: kLabel
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: keyBadge.keyText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption * 0.8
        font.bold: true
      }
    }

    Text {
      textFormat: Text.PlainText
      text: keyBadge.labelText
      color: root.dimColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption * 0.85
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
