package com.follow.clash.service.models

import com.follow.clash.common.GlobalState
import com.follow.clash.common.formatBytes
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
    try {
        val res = getTraffic(onlyStatisticsProxy)
        val traffic = gson.fromJson(res, Traffic::class.java)
        return traffic.getSpeedText(onlyStatisticsProxy)
    } catch (e: Exception) {
        GlobalState.log(e.message + "")
        return ""
    }
}

fun Core.getSpeedDirectTrafficText(): String {
    try {
        val res = getDirectTraffic()
        val Directtraffic = gson.fromJson(res, DirectTraffic::class.java)
        return Directtraffic.speedText
    } catch (e: Throwable) {
        GlobalState.log(e.message + "")
        return ""
    }
}