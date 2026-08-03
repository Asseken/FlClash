package com.follow.clash.service.models

import com.follow.clash.common.GlobalState
import com.follow.clash.core.Core
import com.google.gson.Gson

private val gson = Gson()

data class Traffic(
    val up: Long,
    val down: Long,
)

data class DirectTraffic(
    val up: Long,
    val down: Long,
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

fun Traffic.getSpeedText(isTotal: Boolean): String {
    return if (isTotal) {
        "Proxy: ${up.formatBytes}/s↑  ${down.formatBytes}/s↓"
    } else {
        "Total: ${up.formatBytes}/s↑  ${down.formatBytes}/s↓"
    }
}

val DirectTraffic.speedText: String
    get() = "Direct: ${up.formatBytes}/s↑  ${down.formatBytes}/s↓"

fun Core.getSpeedTrafficText(onlyStatisticsProxy: Boolean): String {
    return runCatching {
        gson.fromJson(getTraffic(onlyStatisticsProxy), Traffic::class.java).getSpeedText(onlyStatisticsProxy)
    }.onFailure { error ->
        GlobalState.log("Unable to read traffic: $error")
    }.getOrDefault("")
}

fun Core.getSpeedDirectTrafficText(onlyStatisticsProxy: Boolean): String {
    return runCatching {
        // onlyStatisticsProxy=true → Direct 直连流量；false → Proxy 代理流量
        val json = if (onlyStatisticsProxy) getDirectTraffic() else getTraffic(true)
        val traffic = gson.fromJson(json, DirectTraffic::class.java)
        if (onlyStatisticsProxy) {
            traffic.speedText
        } else {
            "Proxy: ${traffic.up.formatBytes}/s↑  ${traffic.down.formatBytes}/s↓"
        }
    }.onFailure { error ->
        GlobalState.log("Unable to read direct traffic: $error")
    }.getOrDefault("")
}
