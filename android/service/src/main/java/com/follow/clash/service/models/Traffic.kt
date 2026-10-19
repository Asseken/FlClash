package com.follow.clash.service.models

import com.follow.clash.common.GlobalState
import com.follow.clash.core.Core
import com.google.gson.Gson

private val gson = Gson()

data class Traffic(
    val up: Long,
    val down: Long,
)

data class SplitTrafficText(
    val proxy: String,
    val direct: String,
)

private val Long.formatBytes: String
    get() {
        val units = arrayOf("B", "KB", "MB", "GB", "TB")
        var value = toDouble()
        var unit = 0
        while (value >= 1024 && unit < units.lastIndex) {
            value /= 1024
            unit++
        }
        return if (unit == 0) {
            "${value.toLong()}${units[unit]}"
        } else {
            "%.1f${units[unit]}".format(value)
        }
    }

val Traffic.speedText: String
    get() = "${up.formatBytes}/s↑  ${down.formatBytes}/s↓"

// Sampled a moment apart, so the direct share can come out slightly negative.
fun directTrafficOf(all: Traffic, proxy: Traffic): Traffic = Traffic(
    up = (all.up - proxy.up).coerceAtLeast(0),
    down = (all.down - proxy.down).coerceAtLeast(0),
)

fun splitSpeedText(
    proxy: Traffic,
    all: Traffic,
    proxyLabel: String,
    directLabel: String,
): SplitTrafficText = SplitTrafficText(
    proxy = "$proxyLabel ${proxy.speedText}",
    direct = "$directLabel ${directTrafficOf(all, proxy).speedText}",
)

fun Core.getSplitTrafficText(proxyLabel: String, directLabel: String): SplitTrafficText {
    return runCatching {
        splitSpeedText(
            proxy = gson.fromJson(getTraffic(true), Traffic::class.java),
            all = gson.fromJson(getTraffic(false), Traffic::class.java),
            proxyLabel = proxyLabel,
            directLabel = directLabel,
        )
    }.onFailure { error ->
        GlobalState.log("Unable to read traffic: $error")
    }.getOrDefault(SplitTrafficText("", ""))
}
