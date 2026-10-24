// Model and utility logic for FX Rates plugin

.pragma library

var CURRENCIES = [
  { code: "USD", name: "US Dollar", symbol: "$" },
  { code: "EUR", name: "Euro", symbol: "€" },
  { code: "GBP", name: "British Pound", symbol: "£" },
  { code: "JPY", name: "Japanese Yen", symbol: "¥" },
  { code: "CHF", name: "Swiss Franc", symbol: "Fr" },
  { code: "CAD", name: "Canadian Dollar", symbol: "$" },
  { code: "AUD", name: "Australian Dollar", symbol: "$" },
  { code: "CNY", name: "Chinese Yuan", symbol: "¥" },
  { code: "INR", name: "Indian Rupee", symbol: "₹" },
  { code: "BRL", name: "Brazilian Real", symbol: "R$" },
  { code: "MXN", name: "Mexican Peso", symbol: "$" },
  { code: "KRW", name: "South Korean Won", symbol: "₩" },
  { code: "SGD", name: "Singapore Dollar", symbol: "$" },
  { code: "HKD", name: "Hong Kong Dollar", symbol: "$" },
  { code: "NZD", name: "New Zealand Dollar", symbol: "$" },
  { code: "SEK", name: "Swedish Krona", symbol: "kr" },
  { code: "NOK", name: "Norwegian Krone", symbol: "kr" },
  { code: "DKK", name: "Danish Krone", symbol: "kr" },
  { code: "PLN", name: "Polish Złoty", symbol: "zł" },
  { code: "TRY", name: "Turkish Lira", symbol: "₺" },
  { code: "ZAR", name: "South African Rand", symbol: "R" },
  { code: "THB", name: "Thai Baht", symbol: "฿" },
  { code: "IDR", name: "Indonesian Rupiah", symbol: "Rp" },
  { code: "CZK", name: "Czech Koruna", symbol: "Kč" },
  { code: "ILS", name: "Israeli Shekel", symbol: "₪" },
  { code: "HUF", name: "Hungarian Forint", symbol: "Ft" },
  { code: "PHP", name: "Philippine Peso", symbol: "₱" },
  { code: "MYR", name: "Malaysian Ringgit", symbol: "RM" },
  { code: "RON", name: "Romanian Leu", symbol: "lei" },
  { code: "ISK", name: "Icelandic Króna", symbol: "kr" }
];

var POPULAR_PAIRS = [
  { base: "USD", quote: "EUR" },
  { base: "EUR", quote: "USD" },
  { base: "GBP", quote: "USD" },
  { base: "USD", quote: "JPY" },
  { base: "USD", quote: "CAD" },
  { base: "USD", quote: "CHF" },
  { base: "AUD", quote: "USD" }
];

function currencySymbol(code) {
  for (var i = 0; i < CURRENCIES.length; i++) {
    if (CURRENCIES[i].code === code) return CURRENCIES[i].symbol;
  }
  return code || "";
}

function currencyName(code) {
  for (var i = 0; i < CURRENCIES.length; i++) {
    if (CURRENCIES[i].code === code) return CURRENCIES[i].name;
  }
  return code || "";
}

function formatRate(rate) {
  var num = Number(rate);
  if (!isFinite(num)) return "—";
  if (num >= 1000) return num.toFixed(1);
  if (num >= 100) return num.toFixed(2);
  if (num >= 10) return num.toFixed(3);
  return num.toFixed(4);
}

function formatPreciseRate(rate) {
  var num = Number(rate);
  if (!isFinite(num)) return "—";
  if (num >= 100) return num.toFixed(2);
  return num.toFixed(5);
}

function formatChange(change, changePercent) {
  var ch = Number(change);
  var pct = Number(changePercent);
  if (!isFinite(ch) || !isFinite(pct)) return "0.00%";
  var sign = ch > 0 ? "+" : (ch < 0 ? "-" : "");
  return sign + Math.abs(ch).toFixed(4) + " (" + sign + Math.abs(pct).toFixed(2) + "%)";
}

function getStartDateString(timeframe) {
  var now = new Date();
  var days = 30;
  if (timeframe === "7D") days = 7;
  else if (timeframe === "1M") days = 30;
  else if (timeframe === "3M") days = 90;
  else if (timeframe === "1Y") days = 365;

  var past = new Date(now.getTime() - days * 24 * 3600 * 1000);
  var y = past.getFullYear();
  var m = String(past.getMonth() + 1);
  if (m.length < 2) m = "0" + m;
  var d = String(past.getDate());
  if (d.length < 2) d = "0" + d;
  return y + "-" + m + "-" + d;
}

function parseTimeSeries(jsonString, targetQuote) {
  try {
    var data = JSON.parse(jsonString);
    if (!data || !data.rates) return { success: false, error: "Invalid API response" };

    var points = [];
    for (var dateKey in data.rates) {
      var dayRates = data.rates[dateKey];
      if (dayRates && dayRates[targetQuote] !== undefined) {
        points.push({
          date: dateKey,
          rate: Number(dayRates[targetQuote])
        });
      }
    }

    points.sort(function(a, b) {
      return a.date.localeCompare(b.date);
    });

    if (points.length === 0) {
      return { success: false, error: "No rate data found for " + targetQuote };
    }

    var minRate = points[0].rate;
    var maxRate = points[0].rate;
    var sum = 0;

    for (var i = 0; i < points.length; i++) {
      var r = points[i].rate;
      if (r < minRate) minRate = r;
      if (r > maxRate) maxRate = r;
      sum += r;
    }

    var avgRate = sum / points.length;
    var currentRate = points[points.length - 1].rate;
    var firstRate = points[0].rate;
    var change = currentRate - firstRate;
    var changePercent = firstRate > 0 ? (change / firstRate) * 100 : 0;

    return {
      success: true,
      points: points,
      currentRate: currentRate,
      latestDate: points[points.length - 1].date,
      minRate: minRate,
      maxRate: maxRate,
      avgRate: avgRate,
      change: change,
      changePercent: changePercent,
      isUp: change >= 0
    };
  } catch (e) {
    return { success: false, error: String(e) };
  }
}

function formatDateShort(dateStr) {
  if (!dateStr) return "";
  var parts = dateStr.split("-");
  if (parts.length < 3) return dateStr;
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var mIdx = parseInt(parts[1], 10) - 1;
  var day = parseInt(parts[2], 10);
  return (months[mIdx] || "") + " " + day;
}

function formatDateFull(dateStr) {
  if (!dateStr) return "";
  var parts = dateStr.split("-");
  if (parts.length < 3) return dateStr;
  var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  var mIdx = parseInt(parts[1], 10) - 1;
  var day = parseInt(parts[2], 10);
  var year = parts[0];
  return (months[mIdx] || "") + " " + day + ", " + year;
}
